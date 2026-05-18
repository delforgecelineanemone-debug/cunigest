// ──────────────────────────────────────────────────────────────
// SessionManager — état session locale (V3.0 Auth refactor)
// ──────────────────────────────────────────────────────────────
// Contrairement à un site web, l'app reste "ouverte" en permanence :
//   - la session locale est persistante (cf. LocalLockService)
//   - on ne ré-affiche le verrou QUE si l'app a été en arrière-plan
//     plus longtemps que le délai configuré (15 min par défaut)
//
// États :
//   - Unknown    : pas encore initialisé (au démarrage)
//   - Locked     : verrou à présenter
//   - Unlocked   : l'app est utilisable
//
// L'observation du cycle de vie permet de re-verrouiller au retour
// foreground si nécessaire — sans jamais ré-afficher l'écran de
// connexion cloud.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/widgets.dart';
import 'local_lock_service.dart';

enum SessionStatus { unknown, locked, unlocked }

class SessionManager extends ChangeNotifier with WidgetsBindingObserver {
  SessionManager._() {
    WidgetsBinding.instance.addObserver(this);
  }
  static final SessionManager instance = SessionManager._();

  SessionStatus _status = SessionStatus.unknown;
  SessionStatus get status => _status;

  bool get isUnlocked => _status == SessionStatus.unlocked;
  bool get isLocked => _status == SessionStatus.locked;

  DateTime? _backgroundedAt;

  /// À appeler une fois au démarrage (par SplashScreen) pour décider
  /// si on présente le verrou ou si on ouvre directement l'app.
  Future<SessionStatus> evaluateInitial() async {
    final mode = await LocalLockService.instance.currentMode();
    if (mode == LockMode.none) {
      _setStatus(SessionStatus.unlocked);
    } else {
      _setStatus(SessionStatus.locked);
    }
    return _status;
  }

  /// Appelé par le LockScreen après une authentification réussie
  /// (biométrie ou PIN).
  Future<void> markUnlocked() async {
    await LocalLockService.instance.markUnlocked();
    _setStatus(SessionStatus.unlocked);
  }

  /// Force le verrouillage manuel (ex. bouton "Verrouiller maintenant").
  void lockNow() {
    _setStatus(SessionStatus.locked);
  }

  void _setStatus(SessionStatus s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
  }

  // ── Cycle de vie ─────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt = DateTime.now().toUtc();
    } else if (state == AppLifecycleState.resumed) {
      _onResumed();
    }
  }

  Future<void> _onResumed() async {
    // Si on n'est pas déverrouillé, rien à faire (déjà sur LockScreen).
    if (_status != SessionStatus.unlocked) return;

    final mode = await LocalLockService.instance.currentMode();
    if (mode == LockMode.none) return;

    final delay = await LocalLockService.instance.reLockMinutes();
    // delay < 0  → jamais re-verrouiller pendant la session vivante
    // delay == 0 → re-verrouiller à chaque retour
    if (delay < 0) {
      _backgroundedAt = null;
      return;
    }

    final bg = _backgroundedAt;
    final shouldLock = bg == null ||
        DateTime.now().toUtc().difference(bg).inMinutes >= delay;
    if (shouldLock) {
      debugPrint('SessionManager: re-lock après retour foreground');
      _setStatus(SessionStatus.locked);
    }
    _backgroundedAt = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
