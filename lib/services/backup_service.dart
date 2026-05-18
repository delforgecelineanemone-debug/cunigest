// ──────────────────────────────────────────────────────────────
// Service : Sauvegarde et Restauration de la base de données
// ──────────────────────────────────────────────────────────────
// Deux formats de sauvegarde :
//
//  1. .db  (legacy)  — copie brute SQLCipher, clé liée au Keystore
//                      de l'appareil. Ne fonctionne PAS sur un autre téléphone.
//                      Conservé pour rétrocompatibilité (lecture seule).
//
//  2. .cunigest (V3) — JSON chiffré AES-256-GCM, protégé par mot de passe.
//                      Format binaire : "CGBK" + version + sel + nonce
//                                      + longueur + ciphertext + MAC.
//                      Portable sur n'importe quel appareil.
//
// La méthode `restaurer()` auto-détecte le format via les 4 premiers octets.
// ──────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' hide Hmac;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../database/db_helper.dart';
import '../database/schema.dart';
import 'encryption_key_service.dart';

// ─── Constantes format .cunigest ─────────────────────────────
const _kMagic = [0x43, 0x47, 0x42, 0x4B]; // "CGBK"
const _kFormatVersion = 0x01;
const _kSaltLength = 16;
const _kNonceLength = 12;
const _kMacLength = 16;
const _kPbkdf2Iterations = 100000;
const _kKeyLength = 32; // AES-256

// Tables exclues du backup (données transientes)
const _kSkipTables = {'sync_queue'};

// ─── PBKDF2 top-level pour compute() ─────────────────────────
// Même algo que account_service.dart, retourne des bytes bruts.
List<int> _pbkdf2BytesIsolate(({String password, List<int> salt}) args) {
  final passwordBytes = utf8.encode(args.password);
  final hmac = Hmac(sha256, passwordBytes);
  final salt = args.salt;
  final blocks = <int>[];
  var blockIndex = 1;
  while (blocks.length < _kKeyLength) {
    final saltWithIndex = Uint8List(salt.length + 4);
    saltWithIndex.setAll(0, salt);
    saltWithIndex[salt.length + 0] = (blockIndex >> 24) & 0xFF;
    saltWithIndex[salt.length + 1] = (blockIndex >> 16) & 0xFF;
    saltWithIndex[salt.length + 2] = (blockIndex >> 8) & 0xFF;
    saltWithIndex[salt.length + 3] = blockIndex & 0xFF;
    var u = List<int>.from(hmac.convert(saltWithIndex).bytes);
    final block = List<int>.from(u);
    for (var i = 1; i < _kPbkdf2Iterations; i++) {
      u = List<int>.from(hmac.convert(u).bytes);
      for (var j = 0; j < block.length; j++) {
        block[j] ^= u[j];
      }
    }
    blocks.addAll(block);
    blockIndex++;
  }
  return blocks.take(_kKeyLength).toList();
}

/// Résultat d'une opération de sauvegarde
class BackupResult {
  final bool success;
  final String? path;
  final String? message;
  const BackupResult({required this.success, this.path, this.message});
}

class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  // ═══════════════════════════════════════════════════════════
  // FORMAT .cunigest — EXPORT / IMPORT
  // ═══════════════════════════════════════════════════════════

  /// Exporte toutes les données en format .cunigest chiffré (AES-256-GCM).
  /// Le fichier est utilisable sur n'importe quel appareil via mot de passe.
  Future<BackupResult> exporterChiffre(String motDePasse) async {
    try {
      final db = await DBHelper.instance.database;

      // 1. Lire toutes les tables (sauf sync_queue)
      final data = await _dumpTables(db);

      // 2. Sérialiser + compresser
      final jsonBytes = utf8.encode(jsonEncode(data));
      final compressed = GZipCodec().encode(jsonBytes);

      // 3. Dériver la clé AES depuis le mot de passe
      final salt = List<int>.generate(_kSaltLength, (_) => Random.secure().nextInt(256));
      final keyBytes = await compute(_pbkdf2BytesIsolate, (password: motDePasse, salt: salt));

      // 4. Chiffrer AES-256-GCM
      final algo = AesGcm.with256bits();
      final secretKey = SecretKey(keyBytes);
      final nonce = algo.newNonce();
      final secretBox = await algo.encrypt(compressed, secretKey: secretKey, nonce: nonce);

      // 5. Assembler le fichier binaire
      final ciphertextBytes = secretBox.cipherText;
      final macBytes = secretBox.mac.bytes;

      final header = ByteData(4 + 1 + _kSaltLength + _kNonceLength + 4);
      int offset = 0;
      for (final b in _kMagic) { header.setUint8(offset++, b); }
      header.setUint8(offset++, _kFormatVersion);
      for (final b in salt) { header.setUint8(offset++, b); }
      for (final b in nonce) { header.setUint8(offset++, b); }
      header.setUint32(offset, ciphertextBytes.length, Endian.big);

      final fileBytes = Uint8List.fromList([
        ...header.buffer.asUint8List(),
        ...ciphertextBytes,
        ...macBytes,
      ]);

      // 6. Écrire sur disque
      final destDir = await _getBackupDir();
      final stamp = _timestamp();
      final destPath = p.join(destDir.path, 'cunigest_backup_$stamp.cunigest');
      await File(destPath).writeAsBytes(fileBytes);

      return BackupResult(
        success: true,
        path: destPath,
        message: 'Sauvegarde créée : ${p.basename(destPath)}',
      );
    } catch (e) {
      return BackupResult(success: false, message: 'Échec de la sauvegarde : $e');
    }
  }

  /// Crée une sauvegarde chiffrée puis ouvre la feuille de partage.
  Future<BackupResult> exporterEtPartagerChiffre(String motDePasse) async {
    final result = await exporterChiffre(motDePasse);
    if (!result.success || result.path == null) return result;
    try {
      await Share.shareXFiles(
        [XFile(result.path!)],
        subject: 'Sauvegarde CuniGest (chiffrée)',
        text: 'Sauvegarde protégée par mot de passe — conservez ce mot de passe !',
      );
      return result;
    } catch (e) {
      return BackupResult(
        success: true,
        path: result.path,
        message: 'Sauvegarde créée mais partage indisponible : $e',
      );
    }
  }

  /// Restaure depuis un fichier .cunigest chiffré.
  Future<BackupResult> restaurerChiffre(String chemin, String motDePasse) async {
    try {
      final bytes = Uint8List.fromList(await File(chemin).readAsBytes());

      // Vérifier magic
      if (bytes.length < 4 + 1 + _kSaltLength + _kNonceLength + 4 + _kMacLength) {
        return const BackupResult(success: false, message: 'Fichier .cunigest invalide ou tronqué.');
      }
      for (var i = 0; i < _kMagic.length; i++) {
        if (bytes[i] != _kMagic[i]) {
          return const BackupResult(success: false, message: 'Ce fichier n\'est pas un backup CuniGest.');
        }
      }

      // Parser le header
      final view = ByteData.sublistView(bytes);
      int offset = 4; // après magic
      // ignore version pour l'instant (offset 4)
      offset = 5;
      final salt = bytes.sublist(offset, offset + _kSaltLength);
      offset += _kSaltLength;
      final nonce = bytes.sublist(offset, offset + _kNonceLength);
      offset += _kNonceLength;
      final ciphertextLength = view.getUint32(offset, Endian.big);
      offset += 4;
      if (bytes.length < offset + ciphertextLength + _kMacLength) {
        return const BackupResult(success: false, message: 'Fichier .cunigest tronqué.');
      }
      final ciphertext = bytes.sublist(offset, offset + ciphertextLength);
      final macBytes = bytes.sublist(offset + ciphertextLength, offset + ciphertextLength + _kMacLength);

      // Dériver la clé
      final keyBytes = await compute(
        _pbkdf2BytesIsolate,
        (password: motDePasse, salt: List<int>.from(salt)),
      );

      // Déchiffrer
      final algo = AesGcm.with256bits();
      final secretKey = SecretKey(keyBytes);
      final secretBox = SecretBox(ciphertext, nonce: List<int>.from(nonce), mac: Mac(macBytes));
      List<int> compressed;
      try {
        compressed = await algo.decrypt(secretBox, secretKey: secretKey);
      } catch (_) {
        return const BackupResult(success: false, message: 'Mot de passe incorrect ou fichier corrompu.');
      }

      // Décompresser + parser JSON
      final Map<String, dynamic> data;
      try {
        final jsonStr = utf8.decode(GZipCodec().decode(compressed));
        data = jsonDecode(jsonStr) as Map<String, dynamic>;
      } catch (e) {
        return BackupResult(success: false, message: 'Données corrompues : $e');
      }

      // Restaurer dans la DB
      final db = await DBHelper.instance.database;
      await _restoreTables(db, data);

      return const BackupResult(
        success: true,
        message: 'Restauration réussie. L\'application va recharger les données.',
      );
    } catch (e) {
      return BackupResult(success: false, message: 'Échec de la restauration : $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // FORMAT .db LEGACY — EXPORT / IMPORT
  // ═══════════════════════════════════════════════════════════

  /// Exporte la base SQLCipher brute (même appareil uniquement).
  Future<BackupResult> exporter() async {
    try {
      final dbPath = await DBHelper.instance.databasePath;
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        return const BackupResult(success: false, message: 'La base de données est introuvable.');
      }
      final destDir = await _getBackupDir();
      final stamp = _timestamp();
      final destPath = p.join(destDir.path, 'cunigest_backup_$stamp.db');
      await dbFile.copy(destPath);
      return BackupResult(
        success: true,
        path: destPath,
        message: 'Sauvegarde créée : ${p.basename(destPath)}',
      );
    } catch (e) {
      return BackupResult(success: false, message: 'Échec de la sauvegarde : $e');
    }
  }

  /// Crée une sauvegarde `.db` (legacy) et ouvre le partage.
  Future<BackupResult> exporterEtPartager() async {
    final result = await exporter();
    if (!result.success || result.path == null) return result;
    try {
      await Share.shareXFiles(
        [XFile(result.path!)],
        subject: 'Sauvegarde CuniGest',
        text: 'Sauvegarde de l\'élevage cunicole — à conserver précieusement.',
      );
      return result;
    } catch (e) {
      return BackupResult(
        success: true,
        path: result.path,
        message: 'Sauvegarde créée mais partage indisponible : $e',
      );
    }
  }

  /// Restaure un fichier de sauvegarde.
  /// Auto-détecte le format : .cunigest (chiffré) ou .db (legacy SQLCipher).
  /// Pour le format .cunigest, [motDePasse] est obligatoire.
  Future<BackupResult> restaurer(String sourceFilePath, {String? motDePasse}) async {
    // Détection du format via les 4 premiers octets
    try {
      final bytes = await File(sourceFilePath).openRead(0, 4).first;
      final isCunigest = bytes.length == 4 &&
          bytes[0] == _kMagic[0] && bytes[1] == _kMagic[1] &&
          bytes[2] == _kMagic[2] && bytes[3] == _kMagic[3];

      if (isCunigest) {
        if (motDePasse == null || motDePasse.isEmpty) {
          return const BackupResult(
            success: false,
            message: 'Ce fichier est chiffré. Mot de passe requis.',
          );
        }
        return restaurerChiffre(sourceFilePath, motDePasse);
      }
    } catch (_) {
      // Si la lecture échoue, on tente le format .db classique
    }

    return _restaurerDb(sourceFilePath);
  }

  Future<BackupResult> _restaurerDb(String sourceFilePath) async {
    try {
      final source = File(sourceFilePath);
      if (!await source.exists()) {
        return const BackupResult(success: false, message: 'Fichier de sauvegarde introuvable.');
      }
      final fileSize = await source.length();
      if (fileSize < 4096) {
        return const BackupResult(
          success: false,
          message: 'Fichier invalide : trop petit pour être une sauvegarde CuniGest.',
        );
      }
      final bytes = await source.openRead(0, 16).first;
      final header = String.fromCharCodes(bytes);
      final isPlainSQLite = header.startsWith('SQLite format 3');

      final destDir = await _getBackupDir();
      final stamp = _timestamp();
      final tempPath = p.join(destDir.path, 'cunigest_restore_candidate_$stamp.db');
      final temp = await source.copy(tempPath);
      final valid = await _validateCandidateDb(temp.path, isPlainSQLite: isPlainSQLite);
      if (!valid) {
        try { await temp.delete(); } catch (_) {}
        return const BackupResult(
          success: false,
          message: 'Fichier invalide ou clé incompatible : restauration annulée.',
        );
      }

      final dbPath = await DBHelper.instance.databasePath;
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        final securityPath = p.join(destDir.path, 'cunigest_avant_restore_$stamp.db');
        await dbFile.copy(securityPath);
      }

      await DBHelper.instance.resetForRestore();
      await temp.copy(dbPath);
      try { await temp.delete(); } catch (_) {}

      try {
        await DBHelper.instance.database;
      } catch (e) {
        await DBHelper.instance.resetForRestore();
        return BackupResult(success: false, message: 'Restauration annulée : $e');
      }

      return const BackupResult(
        success: true,
        message: 'Restauration réussie. L\'application va recharger les données.',
      );
    } catch (e) {
      return BackupResult(success: false, message: 'Échec de la restauration : $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // UTILITAIRES
  // ═══════════════════════════════════════════════════════════

  /// Retourne true si le fichier est au format .cunigest (magic bytes "CGBK").
  Future<bool> estFormatChiffre(String chemin) async {
    try {
      final bytes = await File(chemin).openRead(0, 4).first;
      return bytes.length == 4 &&
          bytes[0] == _kMagic[0] && bytes[1] == _kMagic[1] &&
          bytes[2] == _kMagic[2] && bytes[3] == _kMagic[3];
    } catch (_) {
      return false;
    }
  }

  Future<List<File>> listerSauvegardes() async {
    try {
      final dir = await _getBackupDir();
      final files = await dir
          .list()
          .where((e) => e is File && (e.path.endsWith('.db') || e.path.endsWith('.cunigest')))
          .cast<File>()
          .toList();
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      return files;
    } catch (_) {
      return [];
    }
  }

  Future<bool> supprimerSauvegarde(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) { await f.delete(); return true; }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ─── Helpers privés ──────────────────────────────────────

  /// Lit toutes les tables (sauf les tables transientes) et retourne
  /// une Map {tableName: [row, ...]} sérialisable en JSON.
  Future<Map<String, dynamic>> _dumpTables(Database db) async {
    final tables = await db.rawQuery(
      'SELECT name FROM sqlite_master '
      "WHERE type='table' "
      "AND name NOT LIKE 'sqlite_%' "
      "AND name NOT LIKE 'android_%'",
    );
    final result = <String, dynamic>{
      'schema_version': kCurrentDbVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'tables': <String, dynamic>{},
    };
    final tablesMap = result['tables'] as Map<String, dynamic>;
    for (final row in tables) {
      final name = row['name'] as String;
      if (_kSkipTables.contains(name)) continue;
      tablesMap[name] = await db.query(name);
    }
    return result;
  }

  /// Restaure les données d'un backup JSON dans la base courante.
  Future<void> _restoreTables(Database db, Map<String, dynamic> backupData) async {
    final tables = (backupData['tables'] as Map<String, dynamic>?) ?? {};
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      await db.transaction((txn) async {
        // Supprimer toutes les lignes existantes (tables restaurables seulement)
        for (final tableName in tables.keys) {
          try {
            await txn.delete(tableName);
          } catch (_) {
            // Table peut ne pas exister dans une version ancienne — ignorer
          }
        }
        // Réinsérer dans l'ordre du backup
        for (final entry in tables.entries) {
          final tableName = entry.key;
          final rows = entry.value as List<dynamic>;
          for (final row in rows) {
            final rowMap = (row as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, v), // JSON nulls → Dart null → SQLite NULL ✅
            );
            try {
              await txn.insert(
                tableName,
                rowMap,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (_) {
              // Ligne incompatible avec le schéma courant — ignorer
            }
          }
        }
      });
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  Future<bool> _validateCandidateDb(String path, {required bool isPlainSQLite}) async {
    Database? db;
    try {
      final password = isPlainSQLite ? null : await EncryptionKeyService.instance.getOrCreateKey();
      db = await openDatabase(path, password: password, singleInstance: false);
      await db.rawQuery('PRAGMA user_version');
      final requiredTables = ['lapins', 'saillies', 'soins', 'ventes', 'reglages'];
      final placeholders = List.filled(requiredTables.length, '?').join(',');
      final rows = await db.rawQuery(
        'SELECT name FROM sqlite_master WHERE type = ? AND name IN ($placeholders)',
        ['table', ...requiredTables],
      );
      return rows.length == requiredTables.length;
    } catch (_) {
      return false;
    } finally {
      try { await db?.close(); } catch (_) {}
    }
  }

  Future<Directory> _getBackupDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'cunigest_backups'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _timestamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}_${two(n.hour)}${two(n.minute)}';
  }
}
