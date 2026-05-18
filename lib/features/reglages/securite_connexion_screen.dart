// ──────────────────────────────────────────────────────────────
// Écran : Sécurité & Connexion (V3.0 Auth refactor)
// ──────────────────────────────────────────────────────────────
// L'éleveur choisit son niveau de protection quotidien :
//   - Aucun verrou (défaut) : l'app s'ouvre directement
//   - PIN 4-6 chiffres       : verrou local (jamais le mot de passe cloud)
//   - Biométrie              : empreinte / Face ID, fallback PIN
//
// Le compte Supabase n'est PAS lié à ce verrou : le mot de passe
// cloud ne sert qu'à la sauvegarde / nouveau téléphone.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth/local_lock_service.dart';
import '../../ui/cu_ui.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';

class SecuriteConnexionScreen extends StatefulWidget {
  const SecuriteConnexionScreen({super.key});

  @override
  State<SecuriteConnexionScreen> createState() =>
      _SecuriteConnexionScreenState();
}

class _SecuriteConnexionScreenState extends State<SecuriteConnexionScreen> {
  final _lock = LocalLockService.instance;

  bool _loading = true;
  LockMode _mode = LockMode.none;
  bool _hasPin = false;
  bool _bioAvailable = false;
  int _reLockMin = LocalLockService.defaultReLockMinutes;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final mode = await _lock.currentMode();
    final hasPin = await _lock.hasPinSet();
    final bio = await _lock.isBiometryAvailable();
    final rl = await _lock.reLockMinutes();
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _hasPin = hasPin;
      _bioAvailable = bio;
      _reLockMin = rl;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CuAppBar(
        title: 'Sécurité & Connexion',
        emoji: '🔐',
        showSettings: false,
        showActions: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _bandeauInfo(),
                const SizedBox(height: 12),

                // ── Choix du mode ──
                _sectionTitle('Mode de verrouillage'),
                Card(
                  child: Column(
                    children: [
                      _modeTile(
                        icon: Icons.lock_open,
                        title: 'Aucun verrou',
                        subtitle:
                            'L\'app s\'ouvre directement (par défaut, comme WhatsApp).',
                        selected: _mode == LockMode.none,
                        onTap: _choisirAucun,
                      ),
                      const Divider(height: 0),
                      _modeTile(
                        icon: Icons.pin,
                        title: 'Code PIN',
                        subtitle: _hasPin
                            ? '4 à 6 chiffres — configuré'
                            : '4 à 6 chiffres',
                        selected: _mode == LockMode.pin,
                        onTap: _choisirPin,
                      ),
                      const Divider(height: 0),
                      _modeTile(
                        icon: Icons.fingerprint,
                        title: 'Empreinte / Face ID',
                        subtitle: _bioAvailable
                            ? 'Déverrouillage rapide, PIN en secours'
                            : 'Indisponible sur cet appareil',
                        selected: _mode == LockMode.biometry,
                        onTap: _bioAvailable ? _choisirBiometrie : null,
                        disabled: !_bioAvailable,
                      ),
                    ],
                  ),
                ),

                if (_mode != LockMode.none) ...[
                  const SizedBox(height: 16),
                  _sectionTitle('Re-verrouiller après'),
                  Card(
                    child: Column(
                      children: [
                        for (final m in _reLockOptions)
                          RadioListTile<int>(
                            title: Text(_reLockLabel(m)),
                            value: m,
                            groupValue: _reLockMin,
                            onChanged: (v) async {
                              if (v == null) return;
                              await _lock.setReLockMinutes(v);
                              if (mounted) setState(() => _reLockMin = v);
                            },
                          ),
                      ],
                    ),
                  ),

                  if (_hasPin) ...[
                    const SizedBox(height: 16),
                    _sectionTitle('PIN'),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.password,
                            color: AppTheme.primary),
                        title: const Text('Changer le PIN'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _changerPin,
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 24),
              ],
            ).responsive(),
    );
  }

  // ── Construction des tiles ──────────────────────────────────

  Widget _bandeauInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Le mot de passe de ton compte cloud sert UNIQUEMENT à la '
              'sauvegarde et au changement de téléphone. Pour l\'ouverture '
              'quotidienne, utilise un verrou local (PIN ou empreinte).',
              style: TextStyle(
                fontSize: 12.5,
                color: context.cuTextSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          t,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: context.cuTextPrimary,
          ),
        ),
      );

  Widget _modeTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback? onTap,
    bool disabled = false,
  }) {
    return ListTile(
      enabled: !disabled,
      leading: Icon(
        icon,
        color: disabled
            ? Colors.grey
            : (selected ? AppTheme.primary : null),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppTheme.primary)
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  // ── Choix mode ──────────────────────────────────────────────

  Future<void> _choisirAucun() async {
    if (_mode == LockMode.none) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Désactiver le verrou ?',
      message:
          'L\'app s\'ouvrira directement, sans aucune protection locale.\n\n'
          'À éviter si ton téléphone n\'est pas protégé par un verrou système.',
      confirmLabel: 'Désactiver',
      confirmColor: Colors.orange,
    );
    if (!ok) return;
    await _lock.disableLock();
    await _refresh();
    if (mounted) showSuccessSnackBar(context, 'Verrou désactivé');
  }

  Future<void> _choisirPin() async {
    if (_mode == LockMode.pin) return;
    if (!_hasPin) {
      final pin = await _saisirNouveauPin();
      if (pin == null) return;
      await _lock.setupPin(pin);
      await _refresh();
      if (mounted) showSuccessSnackBar(context, 'PIN activé');
      return;
    }
    // PIN déjà configuré (cas : on était en biométrie) → on bascule en PIN seul.
    final ok = await _lock.setMode(LockMode.pin);
    await _refresh();
    if (!mounted) return;
    if (ok) {
      showSuccessSnackBar(context, 'Mode PIN activé');
    } else {
      showErrorSnackBar(context, 'Impossible de basculer en mode PIN');
    }
  }

  Future<void> _choisirBiometrie() async {
    if (!_hasPin) {
      // PIN requis comme fallback
      final pin = await _saisirNouveauPin(
        titre: 'Choisis un PIN de secours',
        sousTitre:
            'Si la biométrie échoue (gants, doigt mouillé, etc.), '
            'le PIN te permettra d\'entrer.',
      );
      if (pin == null) return;
      await _lock.setupPin(pin);
    }
    try {
      final ok = await _lock.enableBiometry();
      await _refresh();
      if (!mounted) return;
      if (ok) {
        showSuccessSnackBar(context, 'Biométrie activée');
      } else {
        showErrorSnackBar(context, 'Authentification biométrique échouée');
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Erreur : $e');
    }
  }

  Future<void> _changerPin() async {
    final actuel = await _saisirPin('Ton PIN actuel');
    if (actuel == null) return;
    if (!await _lock.verifyPin(actuel)) {
      if (mounted) showErrorSnackBar(context, 'PIN incorrect');
      return;
    }
    final nouveau = await _saisirNouveauPin(titre: 'Nouveau PIN');
    if (nouveau == null) return;
    await _lock.setupPin(nouveau);
    await _refresh();
    if (mounted) showSuccessSnackBar(context, 'PIN changé');
  }

  // ── Dialogs de saisie PIN ───────────────────────────────────

  Future<String?> _saisirNouveauPin({
    String titre = 'Choisis ton PIN',
    String? sousTitre,
  }) async {
    final ctrl1 = TextEditingController();
    final ctrl2 = TextEditingController();
    String? erreur;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(titre),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sousTitre != null) ...[
                  Text(
                    sousTitre,
                    style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: ctrl1,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'PIN (4 à 8 chiffres)',
                    prefixIcon: Icon(Icons.pin),
                  ),
                ),
                TextField(
                  controller: ctrl2,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Confirme le PIN',
                    prefixIcon: Icon(Icons.pin),
                  ),
                ),
                if (erreur != null) ...[
                  const SizedBox(height: 8),
                  Text(erreur!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final a = ctrl1.text;
                final b = ctrl2.text;
                if (a.length < 4) {
                  setLocal(() => erreur = 'Minimum 4 chiffres');
                  return;
                }
                if (a != b) {
                  setLocal(() => erreur = 'Les PIN ne correspondent pas');
                  return;
                }
                Navigator.pop(ctx, a);
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
    ctrl1.dispose();
    ctrl2.dispose();
    return result;
  }

  Future<String?> _saisirPin(String titre) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 8,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'PIN',
            prefixIcon: Icon(Icons.pin),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  // ── Options re-lock ─────────────────────────────────────────

  static const _reLockOptions = [0, 5, 15, 60, -1];

  String _reLockLabel(int m) => switch (m) {
        0 => 'Toujours (à chaque ouverture)',
        5 => 'Après 5 min',
        15 => 'Après 15 min',
        60 => 'Après 1 heure',
        -1 => 'Jamais (tant que l\'app est ouverte)',
        _ => '$m min',
      };
}
