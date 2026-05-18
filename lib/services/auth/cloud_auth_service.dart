// ──────────────────────────────────────────────────────────────
// CloudAuthService — orchestration auth cloud (V3.0 Auth refactor)
// ──────────────────────────────────────────────────────────────
// Objectif : que l'utilisateur ne saisisse JAMAIS son mot de passe
// cloud après l'onboarding initial.
//
// Stratégie :
//   1. Au démarrage de l'app, refresh proactif du token Supabase
//      via le refresh_token stocké (valide ~30 jours).
//   2. Si le refresh échoue (refresh_token expiré, mot de passe
//      changé côté autre device), on tente un re-signin SILENCIEUX
//      avec le mot de passe sauvegardé dans flutter_secure_storage.
//   3. Si même ça échoue : l'app reste pleinement utilisable hors
//      ligne ; un état "cloud déconnecté" est exposé pour qu'une
//      bannière discrète invite l'utilisateur à se reconnecter
//      (mini dialog, jamais une page login plein écran).
// ──────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../database/db_helper.dart';
import '../../utils/app_config.dart';
import '../sync_service.dart';

enum CloudHealth {
  /// Pas configuré — utilisateur n'a pas de compte cloud (rare).
  notConfigured,

  /// Token valide ou rafraîchi avec succès.
  healthy,

  /// Token expiré, refresh impossible. App utilisable mais sync KO.
  /// L'utilisateur doit reconnecter son compte (mini dialog).
  needsReconnect,

  /// Pas de réseau au moment du check — on retentera plus tard.
  offline,
}

class CloudAuthService {
  CloudAuthService._();
  static final CloudAuthService instance = CloudAuthService._();

  static const String _kCloudPasswordKey = 'cunigest_account_pwd';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
  );

  CloudHealth _lastHealth = CloudHealth.healthy;
  CloudHealth get lastHealth => _lastHealth;

  /// Lance un refresh proactif silencieux. À appeler une fois au
  /// démarrage (depuis le splash), puis périodiquement par un timer.
  /// Ne lance JAMAIS d'erreur — retourne juste un état.
  Future<CloudHealth> proactiveRefresh() async {
    try {
      final repo = await DBHelper.instance.sync;
      final cfg = await repo.getConfig();

      // Compte cloud absent → rien à faire.
      if (!cfg.hasLocalAccount || !AppConfig.hasSupabaseDefaults) {
        return _setHealth(CloudHealth.notConfigured);
      }

      // 1. Tentative refresh via refresh_token (cas nominal — 99 %).
      if (cfg.refreshToken != null && cfg.refreshToken!.isNotEmpty) {
        final ok = await SyncService.instance.refreshTokenIfPossible();
        if (ok) {
          debugPrint('CloudAuth: token rafraîchi via refresh_token ✅');
          return _setHealth(CloudHealth.healthy);
        }
      }

      // 2. Fallback : re-signin silencieux avec mot de passe stocké.
      final email = cfg.email;
      final pwd = await _storage.read(key: _kCloudPasswordKey);
      if (email != null && email.isNotEmpty && pwd != null && pwd.isNotEmpty) {
        final err = await SyncService.instance.signIn(
          serverUrl: AppConfig.supabaseUrl,
          apiKey: AppConfig.supabaseAnonKey,
          email: email,
          password: pwd,
        );
        if (err == null) {
          debugPrint('CloudAuth: re-signin silencieux réussi ✅');
          return _setHealth(CloudHealth.healthy);
        }
        // Distinguer "pas de réseau" d'une vraie erreur d'identifiants.
        if (err.contains('internet') || err.contains('réessaye')) {
          return _setHealth(CloudHealth.offline);
        }
        debugPrint('CloudAuth: re-signin échec — $err');
      }

      // 3. Échec définitif (mot de passe changé, compte supprimé…).
      return _setHealth(CloudHealth.needsReconnect);
    } catch (e) {
      debugPrint('CloudAuth.proactiveRefresh exception: $e');
      return _setHealth(CloudHealth.offline);
    }
  }

  CloudHealth _setHealth(CloudHealth h) {
    _lastHealth = h;
    return h;
  }

  /// Reconnexion manuelle (depuis bannière "compte déconnecté").
  /// Stocke le mot de passe en secure_storage pour les futurs refresh.
  Future<String?> reconnect({
    required String email,
    required String password,
  }) async {
    if (!AppConfig.hasSupabaseDefaults) {
      return 'Sauvegarde cloud non disponible sur cette version.';
    }
    final err = await SyncService.instance.signIn(
      serverUrl: AppConfig.supabaseUrl,
      apiKey: AppConfig.supabaseAnonKey,
      email: email,
      password: password,
    );
    if (err == null) {
      await _storage.write(key: _kCloudPasswordKey, value: password);
      _setHealth(CloudHealth.healthy);
      return null;
    }
    return err;
  }
}
