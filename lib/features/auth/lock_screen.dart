// ──────────────────────────────────────────────────────────────
// Écran : Verrouillage local (V3.0 Auth refactor)
// ──────────────────────────────────────────────────────────────
// S'affiche au démarrage de l'app SI un verrou local est configuré
// (PIN ou biométrie) ET que la session a expiré.
//
// Comportement :
//   - Mode biométrie : prompt natif déclenché automatiquement à l'ouverture
//   - Mode PIN       : pavé numérique direct
//   - Fallback PIN   : disponible en mode biométrie si l'utilisateur
//                      annule ou échoue à la biométrie
//
// L'écran n'affiche AUCUN champ email/mot-de-passe — celui-ci ne
// concerne que le compte cloud, jamais l'ouverture quotidienne.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/state_providers.dart';
import '../../services/auth/local_lock_service.dart';
import '../../ui/cu_ui.dart';
import '../../utils/theme.dart';
import '../main_scaffold.dart';

/// Écran de déverrouillage.
///
/// Deux modes d'utilisation :
///   1. **Au boot** (depuis SplashScreen) — affiché en plein écran via
///      Navigator.pushReplacement. Le LockScreen pousse alors vers
///      MainScaffold après authentification (`fromBoot: true`, défaut).
///   2. **En re-lock** (superposé via AuthGate) — il suffit de marquer
///      la session unlocked, l'overlay disparaît automatiquement
///      (`fromBoot: false`).
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, this.fromBoot = true});

  final bool fromBoot;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _lock = LocalLockService.instance;

  LockMode _mode = LockMode.none;
  bool _ready = false;
  bool _busy = false;
  bool _bioFailed = false;
  String? _erreurPin;
  final _pinCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final mode = await _lock.currentMode();
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _ready = true;
    });
    // En mode biométrie, on déclenche immédiatement le prompt natif.
    if (mode == LockMode.biometry) {
      // Délai court pour laisser le 1er frame s'afficher (sinon le prompt
      // se déclenche pendant le build et certains constructeurs Android
      // l'ignorent).
      Future.delayed(const Duration(milliseconds: 200), _lancerBiometrie);
    }
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  // ── Authentification ────────────────────────────────────────

  Future<void> _lancerBiometrie() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _bioFailed = false;
    });
    final ok = await _lock.authenticateBiometry(
      reason: 'Déverrouille CuniGest',
    );
    if (!mounted) return;
    if (ok) {
      await _deverrouiller();
    } else {
      setState(() {
        _busy = false;
        _bioFailed = true;
      });
    }
  }

  Future<void> _validerPin() async {
    final pin = _pinCtrl.text;
    if (pin.length < 4) {
      setState(() => _erreurPin = 'PIN trop court');
      return;
    }
    setState(() {
      _busy = true;
      _erreurPin = null;
    });
    final ok = await _lock.verifyPin(pin);
    if (!mounted) return;
    if (ok) {
      await _deverrouiller();
    } else {
      setState(() {
        _busy = false;
        _erreurPin = 'PIN incorrect';
        _pinCtrl.clear();
      });
    }
  }

  Future<void> _deverrouiller() async {
    await ref.read(sessionManagerProvider).markUnlocked();
    if (!mounted) return;
    if (!widget.fromBoot) {
      // Re-lock : on est superposé via AuthGate, l'overlay disparaît
      // automatiquement quand SessionManager.notifyListeners() est appelé.
      return;
    }
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainScaffold(),
        transitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  // ── UI ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 24),
                _logo(),
                const SizedBox(height: 32),
                if (_mode == LockMode.biometry) ..._biometrieBody(),
                if (_mode == LockMode.pin) ..._pinBody(),
              ],
            ),
          ),
        ).responsive(),
      ),
    );
  }

  Widget _logo() => Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Center(child: Text('🐇', style: TextStyle(fontSize: 48))),
      );

  List<Widget> _biometrieBody() {
    return [
      Text(
        'CuniGest',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
      const SizedBox(height: 8),
      Text(
        _bioFailed
            ? 'Authentification annulée'
            : 'Pose ton doigt sur le capteur',
        style: TextStyle(
          fontSize: 14,
          color: context.cuTextSecondary,
        ),
      ),
      const SizedBox(height: 40),
      IconButton(
        iconSize: 72,
        onPressed: _busy ? null : _lancerBiometrie,
        icon: const Icon(
          Icons.fingerprint,
          color: AppTheme.primary,
        ),
      ),
      const SizedBox(height: 24),
      TextButton.icon(
        onPressed: _busy ? null : () => setState(() => _mode = LockMode.pin),
        icon: const Icon(Icons.pin),
        label: const Text('Utiliser le PIN à la place'),
      ),
    ];
  }

  List<Widget> _pinBody() {
    return [
      Text(
        'Entre ton PIN',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
      const SizedBox(height: 24),
      TextField(
        controller: _pinCtrl,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 8,
        textAlign: TextAlign.center,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _busy ? null : _validerPin(),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 24, letterSpacing: 8),
        decoration: InputDecoration(
          counterText: '',
          errorText: _erreurPin,
          prefixIcon: const Icon(Icons.lock_outline),
        ),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _busy ? null : _validerPin,
        icon: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.lock_open),
        label: const Text('Déverrouiller'),
      ),
    ];
  }
}
