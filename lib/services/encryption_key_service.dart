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
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionKeyService {
  static final EncryptionKeyService instance = EncryptionKeyService._();
  EncryptionKeyService._();

  static const String _keyName = 'cunigest_db_key_v1';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      // resetOnError évite de bloquer définitivement si la EncryptedSharedPreferences
      // se corrompt sur certains constructeurs (Xiaomi/Huawei...)
      resetOnError: true,
    ),
  );

  String? _cachedKey;

  /// Récupère la clé existante ou en génère une nouvelle (et la stocke).
  /// Format : 64 caractères hexadécimaux (256 bits).
  Future<String> getOrCreateKey() async {
    if (_cachedKey != null) return _cachedKey!;

    String? existing;
    try {
      existing = await _storage.read(key: _keyName);
    } catch (_) {
      // Si la lecture échoue (clé corrompue, OS trop ancien...),
      // on en génère une nouvelle. La base sera réinitialisée.
      existing = null;
    }

    if (existing != null && existing.isNotEmpty) {
      _cachedKey = existing;
      return existing;
    }

    final newKey = _generate256BitKey();
    await _storage.write(key: _keyName, value: newKey);
    _cachedKey = newKey;
    return newKey;
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
