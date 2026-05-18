// ──────────────────────────────────────────────────────────────
// Écran : Connexion (V2.6 — compte cuniculteur unique)
// ──────────────────────────────────────────────────────────────
// L'éleveur saisit son mot de passe pour déverrouiller l'app.
// Vérification 100 % offline (hash local) — fonctionne sans internet.
// Si du réseau est disponible, le lien cloud se rafraîchit en silence.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:gestion_cunicole/ui/cu_ui.dart';
import '../../database/db_helper.dart';
import '../../services/account_service.dart';
import '../main_scaffold.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  bool _obscurePassword = true;
  String? _erreur;
  String _emailAffiche = '';
  String? _nomAffiche;

  @override
  void initState() {
    super.initState();
    _chargerCompte();
  }

  Future<void> _chargerCompte() async {
    final repo = await DBHelper.instance.sync;
    final cfg = await repo.getConfig();
    if (mounted) {
      setState(() {
        _emailAffiche = cfg.email ?? '';
        _nomAffiche = cfg.nom;
      });
    }
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _connecter() async {
    if (_passwordCtrl.text.isEmpty) {
      setState(() => _erreur = 'Saisis ton mot de passe');
      return;
    }
    setState(() {
      _busy = true;
      _erreur = null;
    });
    final ok = await AccountService.instance.verifierMotDePasse(_passwordCtrl.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScaffold()),
      );
    } else {
      setState(() {
        _busy = false;
        _erreur = 'Mot de passe incorrect';
        _passwordCtrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Center(child: Text('🐇', style: TextStyle(fontSize: 64))),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'CuniGest',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 32),
              if (_nomAffiche != null && _nomAffiche!.isNotEmpty)
                Center(
                  child: Text(
                    'Bonjour $_nomAffiche',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  _emailAffiche,
                  style: TextStyle(fontSize: 13, color: context.cuTextSecondary),
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _busy ? null : _connecter(),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  errorText: _erreur,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ? null : _connecter,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.login),
                label: const Text('Entrer'),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _busy ? null : _afficherAideMotDePasseOublie,
                child: const Text('Mot de passe oublié ?'),
              ),
            ],
          ),
        ),
      ).responsive(),
    );
  }

  void _afficherAideMotDePasseOublie() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Mot de passe oublié'),
        content: const Text(
          'Le mot de passe est stocké uniquement sur ce téléphone, '
          'on ne peut pas le réinitialiser à distance.\n\n'
          'Si tu as une sauvegarde de ta base de données ou si la sync '
          'cloud est active, tu peux réinstaller l\'app et tes données '
          'seront récupérées avec un nouveau mot de passe.\n\n'
          'Sinon, tu peux réinitialiser le compte en effaçant les '
          'données de l\'app dans les Paramètres Android, mais tu '
          'perdras tout ce qui n\'a pas été synchronisé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
