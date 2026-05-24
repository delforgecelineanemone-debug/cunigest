// ──────────────────────────────────────────────────────────────
// Service : Gestion de la clé de chiffrement SQLCipher
// ──────────────────────────────────────────────────────────────
// La base SQLite est chiffrée via SQLCipher. La clé (256 bits)
// est :
// 1. Générée aléatoirement au premier lancement
// 2. Stockée dans flutter_secure_storage (Android Keystore /
//    iOS Keychain) — protégée par le matériel cryptographique
//    du téléphone
// 3. Lue à chaque ouverture de la base
//
// Si l'utilisateur perd l'accès au téléphone, la base est
// inutilisable même copiée. Pour récupérer ses données, il doit
// utiliser une sauvegarde exportée (Réglages → Sauvegarde).
//
// IMPORTANT : la sauvegarde exportée contient la clé en clair
// dans le fichier .db chiffré (SQLCipher embarque la clé via
// PRAGMA key) → la restauration utilise la même clé pour
// déchiffrer. Pour les exports « partagés » sécurisés, voir
// la doc de SQLCipher (`sqlcipher_export`).
// ──────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show getDatabasesPath;
import '../utils/app_config.dart';

/// Nom du fichier de la base SQLite chiffrée. Doit rester aligné avec
/// `DBHelper._initDB('cunicole.db')`. Sert ici de marqueur secondaire :
/// si ce fichier existe, c'est qu'une clé de chiffrement a déjà été
/// utilisée pour le créer (impossible sinon).
const String _kDatabaseFileName = 'cunicole.db';

/// Levée quand une clé de chiffrement a déjà existé (une base chiffrée
/// est présente) mais qu'elle est devenue introuvable — typiquement
/// après une corruption / réinitialisation de la EncryptedSharedPreferences
/// sur certains constructeurs.
///
/// Dans ce cas on NE génère SURTOUT PAS de nouvelle clé : cela écraserait
/// définitivement la clé d'origine et rendrait la base illisible pour
/// toujours. L'UI doit présenter un écran de récupération.
class EncryptionKeyLostException implements Exception {
  final String message;
  EncryptionKeyLostException(this.message);
  @override
  String toString() => 'EncryptionKeyLostException: $message';
}

class EncryptionKeyService {
  static final EncryptionKeyService instance = EncryptionKeyService._();
  EncryptionKeyService._();

  static const String _keyName = 'cunigest_db_key_v1';

  /// Date ISO-8601 de génération de la clé courante — sert au suivi
  /// d'âge pour la rotation périodique (cf. [needsRotation]).
  static const String _keyCreatedAtName = 'cunigest_db_key_created_at';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      // resetOnError évite de bloquer définitivement si la EncryptedSharedPreferences
      // se corrompt sur certains constructeurs (Xiaomi/Huawei...)
      resetOnError: true,
    ),
  );

  String? _cachedKey;

  /// Nom du fichier-marqueur attestant qu'une clé a déjà été générée.
  /// Ce marqueur est posé HORS du secure storage : il survit donc à une
  /// corruption de la EncryptedSharedPreferences et permet de distinguer
  /// « première installation » de « clé perdue ».
  static const String _markerFileName = '.cunigest_key_v1.flag';

  Future<File> _markerFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_markerFileName');
  }

  Future<bool> _markerExists() async {
    try {
      return await (await _markerFile()).exists();
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureMarkerExists() async {
    try {
      final f = await _markerFile();
      if (!await f.exists()) await f.create(recursive: true);
    } catch (_) {/* non bloquant */}
  }

  /// Vérifie l'existence du fichier de base SQLCipher. Présence = preuve
  /// qu'une clé a déjà été générée puisque le fichier ne peut pas être
  /// créé sans `PRAGMA key`.
  ///
  /// Sert de marqueur SECONDAIRE indépendant du fichier flag .cunigest_key_v1.flag :
  /// certains constructeurs Android (Xiaomi, Huawei, OneUI agressifs) nettoient
  /// parfois les fichiers cachés du dossier app support, ce qui ferait perdre
  /// le flag — alors que les fichiers dans `databases/` ne sont jamais
  /// touchés par les nettoyeurs système.
  Future<bool> _databaseFileExists() async {
    try {
      final dbDir = await getDatabasesPath();
      return File(p.join(dbDir, _kDatabaseFileName)).exists();
    } catch (_) {
      return false;
    }
  }

  /// True si AU MOINS un signal indique qu'une clé a déjà été générée.
  /// Double vérification (fichier flag + fichier DB) pour éviter les faux
  /// positifs « première installation » qui régénéreraient une clé et
  /// rendraient la base d'origine irréversiblement illisible.
  Future<bool> _keyHasEverExisted() async {
    if (await _markerExists()) return true;
    if (await _databaseFileExists()) return true;
    return false;
  }

  /// Récupère la clé existante ou en génère une nouvelle (et la stocke).
  /// Format : 64 caractères hexadécimaux (256 bits).
  ///
  /// Lève [EncryptionKeyLostException] si une clé a déjà existé mais
  /// qu'elle est devenue illisible — l'appelant doit alors présenter
  /// un écran de récupération plutôt que de réinitialiser silencieusement.
  Future<String> getOrCreateKey() async {
    if (_cachedKey != null) return _cachedKey!;

    String? existing;
    bool readFailed = false;
    try {
      existing = await _storage.read(key: _keyName);
    } catch (_) {
      // Lecture impossible (corruption, OS trop ancien...). On NE génère
      // pas de nouvelle clé tant qu'on n'a pas vérifié le marqueur.
      readFailed = true;
      existing = null;
    }

    if (existing != null && existing.isNotEmpty) {
      _cachedKey = existing;
      // Backfill : clé créée avant le suivi d'âge (V2.5) → on date
      // d'aujourd'hui pour ne pas forcer une rotation immédiate.
      await _ensureCreatedAtExists();
      await _ensureMarkerExists();
      return existing;
    }

    // Aucune clé lisible. Deux cas possibles :
    //  - première installation authentique  → générer la clé
    //  - une clé a déjà existé (marqueur fichier OU fichier DB présent)
    //    → corruption du secure storage : surtout NE PAS écraser,
    //    lever une exception pour que l'UI propose la récupération.
    if (await _keyHasEverExisted()) {
      throw EncryptionKeyLostException(
        readFailed
            ? 'Lecture de la clé de chiffrement impossible (stockage sécurisé corrompu).'
            : 'Clé de chiffrement absente alors qu\'une base chiffrée existe déjà.',
      );
    }

    final newKey = _generate256BitKey();
    await _storage.write(key: _keyName, value: newKey);
    await _writeCreatedAtNow();
    await _ensureMarkerExists();
    _cachedKey = newKey;
    return newKey;
  }

  /// Efface tout l'état de chiffrement (clé, date, marqueur) pour repartir
  /// d'une base saine après un échec de récupération irréversible.
  /// DESTRUCTIF — à n'appeler que depuis l'écran de récupération, une fois
  /// l'utilisateur prévenu que les données chiffrées seront perdues.
  Future<void> clearForReset() async {
    _cachedKey = null;
    try {
      await _storage.delete(key: _keyName);
    } catch (_) {/* silencieux */}
    try {
      await _storage.delete(key: _keyCreatedAtName);
    } catch (_) {/* silencieux */}
    try {
      final f = await _markerFile();
      if (await f.exists()) await f.delete();
    } catch (_) {/* silencieux */}
  }

  // ──────────────────────────────────────────────────────────
  // Rotation périodique de la clé (P3.19)
  // ──────────────────────────────────────────────────────────

  Future<void> _writeCreatedAtNow() async {
    try {
      await _storage.write(
        key: _keyCreatedAtName,
        value: DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {/* non bloquant */}
  }

  Future<void> _ensureCreatedAtExists() async {
    try {
      final v = await _storage.read(key: _keyCreatedAtName);
      if (v == null || v.isEmpty) await _writeCreatedAtNow();
    } catch (_) {/* non bloquant */}
  }

  /// Âge de la clé courante en jours (0 si date inconnue).
  Future<int> keyAgeInDays() async {
    try {
      final v = await _storage.read(key: _keyCreatedAtName);
      if (v == null || v.isEmpty) return 0;
      final created = DateTime.tryParse(v);
      if (created == null) return 0;
      return DateTime.now().toUtc().difference(created).inDays;
    } catch (_) {
      return 0;
    }
  }

  /// True si la clé dépasse l'âge maximal recommandé (cf. AppConfig).
  Future<bool> needsRotation() async {
    final age = await keyAgeInDays();
    return age >= AppConfig.dbKeyMaxAgeDays;
  }

  /// Génère une nouvelle clé 256 bits SANS la persister — utilisée par
  /// `DBHelper.rotateEncryptionKey()` qui doit d'abord faire le
  /// `PRAGMA rekey` sur la base AVANT de remplacer la clé stockée.
  String generateNewKey() => _generate256BitKey();

  /// Remplace la clé persistée par [newKey] et réinitialise la date.
  /// À n'appeler QU'APRÈS un `PRAGMA rekey` réussi sur la base — sinon
  /// la base devient illisible (ancienne clé / nouvelle clé désalignées).
  Future<void> commitRotatedKey(String newKey) async {
    await _storage.write(key: _keyName, value: newKey);
    await _writeCreatedAtNow();
    _cachedKey = newKey;
  }

  /// Indique si une clé existe déjà (sans la créer).
  Future<bool> hasKey() async {
    try {
      final v = await _storage.read(key: _keyName);
      return v != null && v.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Supprime la clé (DESTRUCTIF — la base devient illisible).
  /// À utiliser uniquement pour un reset complet ou tests.
  Future<void> deleteKey() async {
    _cachedKey = null;
    try {
      await _storage.delete(key: _keyName);
    } catch (_) {/* silencieux */}
  }

  /// Génère une clé hex de 64 caractères (256 bits) cryptographiquement sûre.
  String _generate256BitKey() {
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    return base16(bytes);
  }

  /// Encode des bytes en hexadécimal.
  static String base16(List<int> bytes) {
    const hex = '0123456789abcdef';
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(hex[(b >> 4) & 0xF]);
      sb.write(hex[b & 0xF]);
    }
    return sb.toString();
  }

  /// Format pour PRAGMA key SQLCipher : `x'<hex>'`
  /// Cette syntaxe garantit que SQLCipher utilise les bytes bruts
  /// (256 bits exactement) plutôt que de dériver une clé via PBKDF2.
  String formatForPragma(String hexKey) => "x'$hexKey'";

  // ──────────────────────────────────────────────────────────
  // Aliases
  // ──────────────────────────────────────────────────────────
  String? base64Encode(List<int> bytes) => base64.encode(bytes);
}
