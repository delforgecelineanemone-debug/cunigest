// ──────────────────────────────────────────────────────────────
// LocalLockService — verrou local (V3.0 Auth refactor)
// ──────────────────────────────────────────────────────────────
// Sépare totalement le déverrouillage quotidien (rapide, local)
// du compte cloud Supabase (rare, uniquement pour la sync).
//
// 3 modes au choix de l'utilisateur :
//   - none      : aucun verrou (ouverture directe — défaut)
//   - pin       : PIN 4-6 chiffres (hashé PBKDF2)
//   - biometry  : empreinte / Face ID, fallback PIN si configuré
//
// Le mot de passe cloud n'est JAMAIS demandé pour ouvrir l'app.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import '../../utils/pbkdf2.dart';

enum LockMode { none, pin, biometry }

class LocalLockService {
  LocalLockService._();
  static final LocalLockService instance = LocalLockService._();

  // ── Clés secure storage ─────────────────────────────────────
  static const _kMode = 'cunigest_lock_mode';            // none|pin|biometry
  static const _kPinHash = 'cunigest_lock_pin_hash';     // PBKDF2 du PIN
  static const _kReLockMin = 'cunigest_lock_relock_min'; // re-verrou après N min
  static const _kLastUnlock = 'cunigest_lock_last_unlock'; // ISO timestamp
  static const _kPinFailCount = 'cunigest_lock_pin_fails';   // tentatives PIN
  static const _kPinLockedUntil = 'cunigest_lock_pin_locked_until'; // ISO

  static const int defaultReLockMinutes = 15;

  // ── Brute-force guard ───────────────────────────────────────
  /// Délais (secondes) appliqués après chaque tentative ratée à partir
  /// de la 3e. Indice = (fails - 3). Au-delà du dernier indice = lockout
  /// fixe `kPinLockoutFinalSeconds` (15 min) jusqu'à ce que l'utilisateur
  /// passe par la biométrie ou attende.
  static const List<int> kPinBackoffSeconds = [1, 2, 5, 15, 60, 300];
  static const int kPinLockoutFinalSeconds = 900; // 15 minutes

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
  );

  final LocalAuthentication _auth = LocalAuthentication();

  // ═══════════════════════════════════════════════════════════
  // MODE COURANT
  // ═══════════════════════════════════════════════════════════

  Future<LockMode> currentMode() async {
    final v = await _storage.read(key: _kMode);
    return switch (v) {
      'pin' => LockMode.pin,
      'biometry' => LockMode.biometry,
      _ => LockMode.none,
    };
  }

  Future<void> _setMode(LockMode mode) async {
    await _storage.write(key: _kMode, value: mode.name);
  }

  /// Force le mode (utilisé par l'UI pour repasser de biométrie → PIN seul).
  /// Ne fait rien si les pré-requis manquent (ex. PIN absent pour mode `pin`).
  Future<bool> setMode(LockMode mode) async {
    switch (mode) {
      case LockMode.none:
        await disableLock();
        return true;
      case LockMode.pin:
        if (!await hasPinSet()) return false;
        await _setMode(LockMode.pin);
        return true;
      case LockMode.biometry:
        if (!await hasPinSet()) return false;
        if (!await isBiometryAvailable()) return false;
        await _setMode(LockMode.biometry);
        return true;
    }
  }

  /// Désactive tout verrou (PIN effacé). L'app s'ouvre directement.
  Future<void> disableLock() async {
    await _storage.delete(key: _kPinHash);
    await _setMode(LockMode.none);
  }

  // ═══════════════════════════════════════════════════════════
  // PIN
  // ═══════════════════════════════════════════════════════════

  Future<bool> hasPinSet() async {
    final h = await _storage.read(key: _kPinHash);
    return h != null && h.isNotEmpty;
  }

  /// Définit (ou remplace) le PIN et active le mode PIN.
  /// Le PIN doit faire 4 à 8 chiffres.
  Future<void> setupPin(String pin) async {
    assert(pin.length >= 4 && pin.length <= 8, 'PIN doit faire 4 à 8 chiffres');
    final hash = await pbkdf2Hash(pin);
    await _storage.write(key: _kPinHash, value: hash);
    // Si on était en biometry, on garde biometry (le PIN sert juste de fallback).
    final mode = await currentMode();
    if (mode == LockMode.none) {
      await _setMode(LockMode.pin);
    }
  }

  Future<bool> verifyPin(String pin) async {
    final hash = await _storage.read(key: _kPinHash);
    if (hash == null || hash.isEmpty) return false;
    final ok = await pbkdf2Verify(pin, hash);
    if (ok) {
      await _resetPinFailCount();
    } else {
      await _registerPinFailure();
    }
    return ok;
  }

  // ═══════════════════════════════════════════════════════════
  // BRUTE-FORCE GUARD
  // ═══════════════════════════════════════════════════════════

  /// Renvoie le nombre de secondes restantes avant la prochaine tentative
  /// autorisée. 0 = pas de blocage, l'utilisateur peut saisir son PIN.
  Future<int> pinLockoutSecondsRemaining() async {
    final until = await _storage.read(key: _kPinLockedUntil);
    if (until == null || until.isEmpty) return 0;
    final dt = DateTime.tryParse(until);
    if (dt == null) return 0;
    final diff = dt.difference(DateTime.now().toUtc()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// Nombre de tentatives PIN consécutives ratées.
  Future<int> pinFailCount() async {
    final v = await _storage.read(key: _kPinFailCount);
    return int.tryParse(v ?? '') ?? 0;
  }

  Future<void> _resetPinFailCount() async {
    await _storage.delete(key: _kPinFailCount);
    await _storage.delete(key: _kPinLockedUntil);
  }

  Future<void> _registerPinFailure() async {
    final n = await pinFailCount() + 1;
    await _storage.write(key: _kPinFailCount, value: n.toString());
    // Appliquer un délai à partir de la 3e tentative ratée.
    if (n >= 3) {
      final idx = n - 3;
      final delay = idx < kPinBackoffSeconds.length
          ? kPinBackoffSeconds[idx]
          : kPinLockoutFinalSeconds;
      final lockedUntil =
          DateTime.now().toUtc().add(Duration(seconds: delay)).toIso8601String();
      await _storage.write(key: _kPinLockedUntil, value: lockedUntil);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // BIOMÉTRIE
  // ═══════════════════════════════════════════════════════════

  /// Indique si l'appareil supporte la biométrie ET qu'au moins
  /// une empreinte / un visage est enrôlé.
  Future<bool> isBiometryAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on PlatformException catch (e) {
      debugPrint('LocalLockService.isBiometryAvailable: $e');
      return false;
    }
  }

  /// Active la biométrie. Nécessite qu'un PIN soit déjà configuré
  /// (fallback en cas d'échec biométrique répété).
  Future<bool> enableBiometry() async {
    if (!await hasPinSet()) {
      throw StateError('PIN requis avant d\'activer la biométrie.');
    }
    if (!await isBiometryAvailable()) return false;
    // Test immédiat pour s'assurer que ça fonctionne sur l'appareil
    final ok = await authenticateBiometry(
      reason: 'Active le déverrouillage rapide',
    );
    if (ok) {
      await _setMode(LockMode.biometry);
    }
    return ok;
  }

  /// Lance le prompt biométrique natif.
  /// Retourne true si l'utilisateur est authentifié.
  ///
  /// `stickyAuth: false` (corrigé V2.5) — le prompt ne reste pas ouvert en
  /// arrière-plan, ce qui fermerait la fenêtre d'attaque physique (un voleur
  /// qui force Face ID dans les 15s suivant le vol). Timeout 8s : si l'utilisateur
  /// ne réagit pas dans ce délai, on échoue proprement et on retombe sur PIN.
  Future<bool> authenticateBiometry({String? reason}) async {
    try {
      final result = await _auth
          .authenticate(
            localizedReason: reason ?? 'Déverrouille CuniGest',
            options: const AuthenticationOptions(
              biometricOnly: true,
              stickyAuth: false,
              useErrorDialogs: true,
            ),
            authMessages: const [
              AndroidAuthMessages(
                signInTitle: 'CuniGest',
                cancelButton: 'Annuler',
                biometricHint: '',
                biometricNotRecognized: 'Empreinte non reconnue',
                biometricSuccess: 'Authentifié',
              ),
              IOSAuthMessages(
                cancelButton: 'Annuler',
                lockOut: 'Réessaye plus tard',
              ),
            ],
          )
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => false,
          );
      return result;
    } on PlatformException catch (e) {
      debugPrint('LocalLockService.authenticateBiometry: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // POLITIQUE RE-LOCK
  // ═══════════════════════════════════════════════════════════

  Future<int> reLockMinutes() async {
    final v = await _storage.read(key: _kReLockMin);
    return int.tryParse(v ?? '') ?? defaultReLockMinutes;
  }

  Future<void> setReLockMinutes(int minutes) async {
    await _storage.write(key: _kReLockMin, value: minutes.toString());
  }

  /// Enregistre le moment où l'utilisateur vient de déverrouiller l'app.
  Future<void> markUnlocked() async {
    await _storage.write(
      key: _kLastUnlock,
      value: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<DateTime?> lastUnlockedAt() async {
    final v = await _storage.read(key: _kLastUnlock);
    if (v == null || v.isEmpty) return null;
    return DateTime.tryParse(v);
  }

  /// True si le verrou doit être présenté maintenant.
  /// - mode none           → false
  /// - reLockMinutes == 0  → true (verrouille à chaque retour foreground)
  /// - reLockMinutes < 0   → false (jamais re-verrouiller dans la session)
  /// - sinon               → true si écoulé > reLockMinutes depuis dernier unlock
  Future<bool> shouldLockNow() async {
    final mode = await currentMode();
    if (mode == LockMode.none) return false;
    final delay = await reLockMinutes();
    if (delay < 0) return false;
    if (delay == 0) return true;
    final last = await lastUnlockedAt();
    if (last == null) return true;
    return DateTime.now().toUtc().difference(last).inMinutes >= delay;
  }
}
