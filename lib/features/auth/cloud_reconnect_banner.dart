// ──────────────────────────────────────────────────────────────
// CloudReconnectBanner — bannière discrète (V3.0 Auth refactor)
// ──────────────────────────────────────────────────────────────
// S'affiche sur le Dashboard SI :
//   - le compte cloud est configuré
//   - mais le refresh_token a expiré ET le re-signin silencieux a échoué
//
// Tap → mini dialog email/mot-de-passe (PAS une page login plein écran).
// L'app reste 100 % utilisable hors ligne pendant ce temps.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../services/account_service.dart';
import '../../services/auth/cloud_auth_service.dart';
import '../../ui/cu_ui.dart';
import '../../widgets/common_widgets.dart';
import 'google_sign_in_button.dart';

class CloudReconnectBanner extends StatefulWidget {
  const CloudReconnectBanner({super.key});

  @override
  State<CloudReconnectBanner> createState() => _CloudReconnectBannerState();
}

class _CloudReconnectBannerState extends State<CloudReconnectBanner> {
  CloudHealth _health = CloudHealth.healthy;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    // On lit l'état déjà calculé au démarrage par le splash, sans
    // déclencher d'appel réseau supplémentaire.
    final h = CloudAuthService.instance.lastHealth;
    if (mounted) {
      setState(() {
        _health = h;
        _checked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || _health != CloudHealth.needsReconnect) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          CuSpacing.md, 0, CuSpacing.md, CuSpacing.sm),
      child: CuAlertBanner(
        message: 'Sauvegarde cloud déconnectée — reconnecte ton compte',
        level: CuAlertLevel.warning,
        icon: Icons.cloud_off,
        actionLabel: 'Reconnecter',
        onAction: _openReconnectDialog,
      ),
    );
  }

  Future<void> _openReconnectDialog() async {
    final repo = await DBHelper.instance.sync;
    final cfg = await repo.getConfig();
    if (!mounted) return;

    final emailCtrl = TextEditingController(text: cfg.email ?? '');
    final pwdCtrl = TextEditingController();
    bool obscure = true;
    bool busy = false;
    String? erreur;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Reconnecter le compte cloud'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Reconnecte-toi pour reprendre la sauvegarde cloud. '
                  'Cette saisie est rare (~1 fois par mois maximum).',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                GoogleSignInButton(
                  enabled: !busy,
                  onResult: (r) async {
                    if (r.cancelled) return;
                    if (!r.isSuccess) {
                      setLocal(() => erreur = r.error);
                      return;
                    }
                    await AccountService.instance.creerCompteGoogle(
                      email: r.email ?? '',
                      nom: r.displayName,
                      session: r.session!,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      setState(() => _health = CloudHealth.healthy);
                      showSuccessSnackBar(context, 'Compte reconnecté ✅');
                    }
                  },
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('ou email',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pwdCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      tooltip: obscure
                          ? 'Afficher le mot de passe'
                          : 'Masquer le mot de passe',
                      onPressed: () => setLocal(() => obscure = !obscure),
                    ),
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
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Plus tard'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setLocal(() {
                        busy = true;
                        erreur = null;
                      });
                      final err =
                          await CloudAuthService.instance.reconnect(
                        email: emailCtrl.text.trim(),
                        password: pwdCtrl.text,
                      );
                      if (err == null) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          setState(() => _health = CloudHealth.healthy);
                          showSuccessSnackBar(context, 'Compte reconnecté ✅');
                        }
                      } else {
                        setLocal(() {
                          busy = false;
                          erreur = err;
                        });
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Reconnecter'),
            ),
          ],
        ),
      ),
    );
    emailCtrl.dispose();
    pwdCtrl.dispose();
  }
}
