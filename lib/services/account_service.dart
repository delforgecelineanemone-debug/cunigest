// ──────────────────────────────────────────────────────────────
// AccountService — Compte cuniculteur unique (V3.0)
// ──────────────────────────────────────────────────────────────
// Hashage : PBKDF2-HMAC-SHA256 (100 000 itérations, sel 16 bytes par compte).
// Migration transparente : les anciens comptes SHA-256 sont migrés
// automatiquement lors du premier login réussi après mise à jour.
//
// Format hash stocké : "pbkdf2$100000$<base64url(sel)>$<base64url(clé)>"
// Ancien format (SHA-256) : 64 chars hex sans préfixe "pbkdf2$"
// ──────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../database/db_helper.dart';
import '../models/sync_entry.dart';
import '../utils/app_config.dart';
import 'sync_service.dart';

// ─── Constantes PBKDF2 ───────────────────────────────────────
const int _kIterations = 100000;
const int _kKeyLength = 32; // bytes (256 bits)
const int _kSaltLength = 16; // bytes (128 bits)
const String _kPbkdf2Prefix = 'pbkdf2\$';
const String _kLegacySalt = 'cunigest_v3_account_salt_8a2d';

// ─── PBKDF2-HMAC-SHA256 — top-level pour compute() ───────────
// Reçoit un record Dart 3.0 {password, salt}.
// Retourne "pbkdf2$iterations$base64url(sel)$base64url(clé)".
String _pbkdf2HashIsolate(({String password, List<int> salt}) args) {
  final passwordBytes = utf8.encode(args.password);
  final hmac = Hmac(sha256, passwordBytes);
  final salt = args.salt;

  final blocks = <int>[];
  var blockIndex = 1;

  while (blocks.length < _kKeyLength) {
    // U1 = HMAC(password, salt || INT(blockIndex, 4 bytes big-endian)
    final saltWithIndex = Uint8List(salt.length + 4);
    saltWithIndex.setAll(0, salt);
    saltWithIndex[salt.length + 0] = (blockIndex >> 24) & 0xFF;
    saltWithIndex[salt.length + 1] = (blockIndex >> 16) & 0xFF;
    saltWithIndex[salt.length + 2] = (blockIndex >> 8) & 0xFF;
    saltWithIndex[salt.length + 3] = blockIndex & 0xFF;

    var u = List<int>.from(hmac.convert(saltWithIndex).bytes);
    final block = List<int>.from(u);

    for (var i = 1; i < _kIterations; i++) {
      u = List<int>.from(hmac.convert(u).bytes);
      for (var j = 0; j < block.length; j++) {
        block[j] ^= u[j];
      }
    }

    blocks.addAll(block);
    blockIndex++;
  }

  final derived = blocks.take(_kKeyLength).toList();
  final saltB64 = base64Url.encode(salt);
  final hashB64 = base64Url.encode(derived);
  return '$_kPbkdf2Prefix$_kIterations\$$saltB64\$$hashB64';
}

class AccountService {
  AccountService._();
  static final AccountService instance = AccountService._();

  static const String _kCloudPasswordKey = 'cunigest_account_pwd';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true, resetOnError: true),
  );

  // ─── Hashage ──────────────────────────────────────────────

  /// Génère un nouveau hash PBKDF2 dans un isolate (non bloquant pour l'UI).
  Future<String> _hashPbkdf2(String password) async {
    final salt = List<int>.generate(
      _kSaltLength,
      (_) => Random.secure().nextInt(256),
    );
    return compute(_pbkdf2HashIsolate, (password: password, salt: salt));
  }

  /// Vérifie un mot de passe contre un hash PBKDF2 stocké.
  /// Le sel est extrait du hash lui-même.
  Future<bool> _verifyPbkdf2(String password, String storedHash) async {
    try {
      final parts = storedHash.split('\$');
      if (parts.length != 4 || parts[0] != 'pbkdf2') return false;
      final salt = List<int>.from(base64Url.decode(parts[2]));
      final candidate = await compute(
        _pbkdf2HashIsolate,
        (password: password, salt: salt),
      );
      return candidate == storedHash;
    } catch (e) {
      debugPrint('AccountService._verifyPbkdf2 erreur : $e');
      return false;
    }
  }

  /// Hash SHA-256 legacy — utilisé uniquement pour la migration.
  static String _legacySha256(String password) {
    final bytes = utf8.encode(_kLegacySalt + password);
    return sha256.convert(bytes).toString();
  }

  /// Détecte si le hash stocké est dans l'ancien format SHA-256.
  static bool _isLegacyHash(String hash) => !hash.startsWith(_kPbkdf2Prefix);

  // ─── Config DB ────────────────────────────────────────────

  Future<SyncConfig> _getConfig() async {
    final repo = await DBHelper.instance.sync;
    return repo.getConfig();
  }

  Future<void> _saveConfig(SyncConfig cfg) async {
    final repo = await DBHelper.instance.sync;
    await repo.updateConfig(cfg);
  }

  // ═══════════════════════════════════════════════════════════
  // CRÉATION / CONNEXION DU COMPTE LOCAL
  // ═══════════════════════════════════════════════════════════

  /// Indique si un compte local est déjà créé sur ce téléphone.
  Future<bool> compteExiste() async {
    final cfg = await _getConfig();
    return cfg.hasLocalAccount;
  }

  /// Crée le compte local avec hash PBKDF2.
  /// Lance le lien cloud en tâche de fond.
  Future<void> creerCompte({
    required String email,
    required String nom,
    required String motDePasse,
  }) async {
    final hash = await _hashPbkdf2(motDePasse);
    final cfg = await _getConfig();
    await _saveConfig(cfg.copyWith(
      email: email,
      nom: nom,
      passwordHash: hash,
      enabled: true,
      clearAuth: true,
    ));
    await _storage.write(key: _kCloudPasswordKey, value: motDePasse);
    unawaited(tenterLienCloud());
  }

  /// Vérifie le mot de passe contre le hash local.
  ///
  /// Migration automatique : si l'ancien format SHA-256 est détecté et que
  /// le mot de passe est correct, le hash est upgradé en PBKDF2 silencieusement.
  Future<bool> verifierMotDePasse(String motDePasse) async {
    final cfg = await _getConfig();
    final storedHash = cfg.passwordHash;
    if (storedHash == null || storedHash.isEmpty) return false;

    bool ok;
    if (_isLegacyHash(storedHash)) {
      ok = _legacySha256(motDePasse) == storedHash;
      if (ok) {
        // Migration transparente SHA-256 → PBKDF2
        debugPrint('AccountService : migration SHA-256 → PBKDF2…');
        final newHash = await _hashPbkdf2(motDePasse);
        await _saveConfig(cfg.copyWith(passwordHash: newHash));
        debugPrint('AccountService : migration PBKDF2 terminée.');
      }
    } else {
      ok = await _verifyPbkdf2(motDePasse, storedHash);
    }

    if (ok) {
      await _storage.write(key: _kCloudPasswordKey, value: motDePasse);
      unawaited(tenterLienCloud());
    }
    return ok;
  }

  /// Supprime totalement le compte (local + déconnexion cloud).
  /// Les données locales (lapins, etc.) restent intactes.
  Future<void> supprimerCompte() async {
    final cfg = await _getConfig();
    await _saveConfig(cfg.copyWith(
      email: '',
      nom: '',
      passwordHash: '',
      clearAuth: true,
      enabled: false,
    ));
    try {
      await _storage.delete(key: _kCloudPasswordKey);
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════
  // LIEN AUTOMATIQUE AU CLOUD
  // ═══════════════════════════════════════════════════════════

  /// Tente de lier le compte local au cloud Supabase.
  /// Silencieux en cas d'échec (pas de réseau, etc.).
  Future<void> tenterLienCloud() async {
    try {
      final cfg = await _getConfig();
      if (cfg.isCloudLinked) return;
      if (!cfg.hasLocalAccount) return;
      if (!AppConfig.hasSupabaseDefaults) return;

      final motDePasse = await _storage.read(key: _kCloudPasswordKey);
      if (motDePasse == null || motDePasse.isEmpty) return;

      final email = cfg.email!;

      final signUpErr = await SyncService.instance.signUp(
        serverUrl: AppConfig.supabaseUrl,
        apiKey: AppConfig.supabaseAnonKey,
        email: email,
        password: motDePasse,
      );

      if (signUpErr == null) {
        await SyncService.instance.signIn(
          serverUrl: AppConfig.supabaseUrl,
          apiKey: AppConfig.supabaseAnonKey,
          email: email,
          password: motDePasse,
        );
        debugPrint('AccountService : compte créé et lié au cloud.');
        return;
      }

      final signInErr = await SyncService.instance.signIn(
        serverUrl: AppConfig.supabaseUrl,
        apiKey: AppConfig.supabaseAnonKey,
        email: email,
        password: motDePasse,
      );
      if (signInErr == null) {
        debugPrint('AccountService : compte existant rejoint sur le cloud.');
      } else {
        debugPrint('AccountService : lien cloud impossible — $signInErr');
      }
    } catch (e) {
      debugPrint('AccountService.tenterLienCloud erreur : $e');
    }
  }
}

/// Lance un Future sans attendre, sans warning du linter.
void unawaited(Future<void> f) {
  f.catchError((_) {});
}
