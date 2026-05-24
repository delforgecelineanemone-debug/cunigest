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
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
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

/// Résultat d'une tentative de lien entre le compte local et le cloud Supabase.
/// Distingue les cas pour que l'UI puisse réagir : silence en cas de
/// non-applicabilité, avertissement utilisateur en cas d'échec réel.
enum CloudLinkOutcome {
  /// Le compte local est lié au cloud (signUp ou signIn Supabase OK).
  success,

  /// Aucune tentative n'a été faite (pas de compte local, pas de config
  /// Supabase compilée, ou mot de passe absent → compte Google). Pas une
  /// erreur utilisateur ; l'app reste pleinement fonctionnelle offline.
  notApplicable,

  /// Tentative effectuée mais échouée (pas de réseau, identifiants
  /// invalides, serveur down). L'utilisateur doit en être informé pour
  /// pouvoir réessayer plus tard depuis Réglages → Sauvegarde cloud.
  failed,
}

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

  /// Compte les lignes de données métier présentes localement (cheptel,
  /// reproduction, santé, ventes, lots, cages…).
  ///
  /// Sert, à la création d'un compte, à détecter si l'appareil contient
  /// déjà des données — auquel cas on DOIT demander à l'utilisateur si
  /// elles lui appartiennent avant tout envoi vers le cloud.
  Future<int> compterDonneesLocales() async {
    try {
      final db = await DBHelper.instance.database;
      const tables = [
        'lapins', 'saillies', 'soins', 'ventes', 'depenses',
        'lots', 'cages', 'batiments', 'clapiers', 'stocks',
      ];
      var total = 0;
      for (final t in tables) {
        try {
          final r = await db.rawQuery('SELECT COUNT(*) AS n FROM $t');
          total += (r.first['n'] as int?) ?? 0;
        } catch (_) {/* table absente — ignore */}
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Crée le compte local avec hash PBKDF2, puis tente le lien cloud.
  ///
  /// Retourne le résultat de la tentative de lien — l'appelant DOIT vérifier
  /// la valeur pour informer l'utilisateur en cas d'échec (sinon il croit
  /// avoir un compte cloud sans en avoir un, et perd ses données à la
  /// réinstallation).
  Future<CloudLinkOutcome> creerCompte({
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
    // Lien cloud uniquement. Le push initial des données locales est géré
    // SÉPARÉMENT par l'onboarding, APRÈS un consentement explicite : on ne
    // pousse jamais de données vers le cloud sans l'accord de l'éleveur.
    return tenterLienCloud();
  }

  /// Crée (ou met à jour) le compte local après une connexion Google
  /// réussie. Pas de mot de passe local — la session Supabase fait foi.
  ///
  /// La session passée en paramètre est déjà persistée par supabase_flutter
  /// dans SharedPreferences ; on la recopie aussi dans `sync_config` pour
  /// que l'ancien `SyncService` (push/pull REST) puisse continuer à
  /// fonctionner sans refactor immédiat.
  Future<void> creerCompteGoogle({
    required String email,
    required String? nom,
    required sb.Session session,
  }) async {
    final cfg = await _getConfig();

    // Détection changement d'utilisateur cloud :
    // - Si on avait déjà un userId et qu'il est différent du nouveau,
    //   les rows locales (déjà push à l'ancien userId) doivent être
    //   re-pushées au nouveau.
    final isUserChange =
        cfg.userId != null && cfg.userId!.isNotEmpty && cfg.userId != session.user.id;
    if (isUserChange) {
      debugPrint(
          'AccountService 🔄 changement de userId cloud : ${cfg.userId} → ${session.user.id}');
    }

    await _saveConfig(cfg.copyWith(
      email: email,
      nom: nom ?? cfg.nom,
      passwordHash: SyncConfig.googleOAuthSentinel,
      enabled: true,
      serverUrl: AppConfig.supabaseUrl,
      apiKey: AppConfig.supabaseAnonKey,
      userId: session.user.id,
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    ));
    // Marque l'onboarding comme terminé : avec un compte Google, on peut
    // sauter directement à MainScaffold même si l'utilisateur ferme
    // l'app avant d'avoir cliqué « Commencer ».
    try {
      final profilRepo = await DBHelper.instance.profil;
      final r = await profilRepo.getReglages();
      if (!r.onboardingDone) {
        await profilRepo.updateReglages(r.copyWith(onboardingDone: true));
      }
    } catch (e) {
      debugPrint('AccountService : updateReglages échec : $e');
    }
    debugPrint('AccountService : compte Google créé (${session.user.id})');
    // AUCUN push automatique : l'onboarding demande explicitement à
    // l'utilisateur si les données locales lui appartiennent avant tout
    // envoi vers le cloud. Pousser en silence des données qui ne sont pas
    // les siennes (données de test, ancien compte) est un défaut grave.
  }

  /// Push initial après création de compte.
  /// Scan toutes les tables locales et enqueue les rows non encore
  /// connues du cloud, puis déclenche une sync immédiate.
  ///
  /// Si [onProgress] est fourni, émet le SyncProgress pendant le push
  /// (utile pour afficher une modale dans l'onboarding).
  ///
  /// Idempotent : ne ré-enqueue pas les rows déjà connues.
  Future<SyncReport?> doInitialPush({
    void Function(SyncProgress)? onProgress,
    bool forceAll = false,
  }) async {
    try {
      debugPrint(
          'AccountService 🚀 doInitialPush — scan des tables (forceAll=$forceAll)…');
      onProgress?.call(const SyncProgress(
        phase: 'preparing',
        processed: 0,
        total: 0,
        message: 'Analyse de tes données locales…',
      ));
      final added = await SyncService.instance.enqueueAllExistingRows(
        forceAll: forceAll,
      );
      debugPrint('AccountService 🚀 $added élément(s) ajouté(s) à la file');
      if (added == 0) {
        // Rien à pousser (cas user fraichement créé sans données locales).
        // On déclenche quand même une sync pour faire le pull si jamais.
        onProgress?.call(const SyncProgress(
          phase: 'preparing',
          processed: 0,
          total: 0,
          message: 'Aucune donnée à envoyer.',
        ));
      }
      debugPrint('AccountService 🚀 lancement synchroniser()…');
      final report = await SyncService.instance.synchroniser(
        onProgress: onProgress,
      );
      debugPrint(
          'AccountService 🚀 résultat : success=${report.success} pushed=${report.pushed} errors=${report.errors} msg="${report.message}"');
      return report;
    } catch (e, st) {
      debugPrint('AccountService 🚀 doInitialPush KO : $e\n$st');
      return null;
    }
  }

  /// Synchronise la session courante de supabase_flutter dans `sync_config`
  /// — appelé sur authStateChange pour que le SyncService legacy ait
  /// toujours les bons tokens.
  Future<void> syncFromSupabaseSession(sb.Session? session) async {
    if (session == null) return;
    final cfg = await _getConfig();
    await _saveConfig(cfg.copyWith(
      serverUrl: AppConfig.supabaseUrl,
      apiKey: AppConfig.supabaseAnonKey,
      userId: session.user.id,
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    ));
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
  ///
  /// Retourne un [CloudLinkOutcome] pour permettre à l'appelant (onboarding,
  /// écran de connexion) d'afficher un avertissement si l'utilisateur croit
  /// avoir un compte cloud mais que le lien a échoué. N'élève jamais.
  Future<CloudLinkOutcome> tenterLienCloud() async {
    try {
      final cfg = await _getConfig();
      if (cfg.isCloudLinked) return CloudLinkOutcome.success;
      if (!cfg.hasLocalAccount) return CloudLinkOutcome.notApplicable;
      if (!AppConfig.hasSupabaseDefaults) return CloudLinkOutcome.notApplicable;

      final motDePasse = await _storage.read(key: _kCloudPasswordKey);
      if (motDePasse == null || motDePasse.isEmpty) {
        return CloudLinkOutcome.notApplicable;
      }

      final email = cfg.email!;

      final signUpErr = await SyncService.instance.signUp(
        serverUrl: AppConfig.supabaseUrl,
        apiKey: AppConfig.supabaseAnonKey,
        email: email,
        password: motDePasse,
      );

      if (signUpErr == null) {
        final signInErr = await SyncService.instance.signIn(
          serverUrl: AppConfig.supabaseUrl,
          apiKey: AppConfig.supabaseAnonKey,
          email: email,
          password: motDePasse,
        );
        if (signInErr == null) {
          debugPrint('AccountService : compte créé et lié au cloud.');
          return CloudLinkOutcome.success;
        }
        debugPrint(
            'AccountService : signUp OK mais signIn KO — $signInErr');
        return CloudLinkOutcome.failed;
      }

      final signInErr = await SyncService.instance.signIn(
        serverUrl: AppConfig.supabaseUrl,
        apiKey: AppConfig.supabaseAnonKey,
        email: email,
        password: motDePasse,
      );
      if (signInErr == null) {
        debugPrint('AccountService : compte existant rejoint sur le cloud.');
        return CloudLinkOutcome.success;
      }
      debugPrint('AccountService : lien cloud impossible — $signInErr');
      return CloudLinkOutcome.failed;
    } catch (e) {
      debugPrint('AccountService.tenterLienCloud erreur : $e');
      return CloudLinkOutcome.failed;
    }
  }
}

/// Lance un Future sans attendre, sans warning du linter.
/// Accepte n'importe quel Future (y compris Future<CloudLinkOutcome>) car
/// l'appelant choisit explicitement de ne pas attendre la valeur retournée.
void unawaited(Future<Object?> f) {
  f.catchError((Object _) {});
}
