// OnboardingScreen V3 — CuniUI
// Logique inchangée · UI redesignée avec CuniUI tokens

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/db_helper.dart';
import '../models/reglages.dart';
import '../providers/state_providers.dart';
import '../services/account_service.dart';
import '../ui/cu_ui.dart';
import '../widgets/common_widgets.dart';
import 'main_scaffold.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;
  String _themeMode = 'system';

  // Compte
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _compteCree = false;
  bool _busy = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nomCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _terminer() async {
    final state = ref.read(reglagesProvider.notifier);
    final db = DBHelper.instance;
    final r = await db.getReglages();
    await db.updateReglages(
      r.copyWith(onboardingDone: true, themeMode: _themeMode),
    );
    await state.refresh();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainScaffold()),
    );
  }

  Future<void> _suivant() async {
    if (_page == 1 && !_compteCree) {
      await _creerCompte();
      return;
    }
    if (_page < 3) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else {
      _terminer();
    }
  }

  Future<void> _creerCompte() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AccountService.instance.creerCompte(
        email: _emailCtrl.text.trim(),
        nom: _nomCtrl.text.trim(),
        motDePasse: _passCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _compteCree = true;
        _busy = false;
      });
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorSnackBar(context, 'Création du compte impossible.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? CuColors.bgDark : CuColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: _compteCree
                    ? null
                    : const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _bienvenue(),
                  _creationCompte(),
                  _choixTheme(),
                  _conseils(),
                ],
              ),
            ),
            // ── Indicateurs de page ──
            Padding(
              padding: const EdgeInsets.only(bottom: CuSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final actif = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: actif ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: actif
                          ? CuColors.primary
                          : CuColors.primary.withValues(alpha: 0.25),
                      borderRadius: CuRadius.fullAll,
                    ),
                  );
                }),
              ),
            ),
            // ── Navigation ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  CuSpacing.xl, 0, CuSpacing.xl, CuSpacing.xl),
              child: Row(
                children: [
                  if (_page >= 2 && _page < 3)
                    TextButton(
                      onPressed: _busy ? null : _terminer,
                      style: TextButton.styleFrom(
                          foregroundColor: CuColors.textSecondaryLight),
                      child: const Text('Passer'),
                    ),
                  const Spacer(),
                  _busy
                      ? const SizedBox(
                          width: 120,
                          height: 48,
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: CuColors.primary,
                              ),
                            ),
                          ),
                        )
                      : CuButton(
                          label: _page == 3
                              ? 'Commencer'
                              : (_page == 1 && !_compteCree
                                  ? 'Créer mon compte'
                                  : 'Suivant'),
                          icon: _page == 3
                              ? Icons.check
                              : (_page == 1 && !_compteCree
                                  ? Icons.person_add
                                  : Icons.arrow_forward),
                          onPressed: _suivant,
                          size: CuButtonSize.lg,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Page 0 : Bienvenue ─────────────────────────────────────

  Widget _bienvenue() {
    return Padding(
      padding: const EdgeInsets.all(CuSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  CuColors.primary.withValues(alpha: 0.18),
                  CuColors.primary.withValues(alpha: 0.04),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🐇', style: TextStyle(fontSize: 88)),
            ),
          ),
          const SizedBox(height: CuSpacing.x2l),
          Text(
            'Bienvenue sur CuniGest',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: CuSpacing.md),
          Text(
            'Ton élevage de lapins, organisé.\n'
            'Cheptel, reproduction, santé, ventes — '
            'tout au même endroit, et ça marche sans internet.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? CuColors.textSecondaryDark
                      : CuColors.textSecondaryLight,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  // ─── Page 1 : Création du compte ────────────────────────────

  Widget _creationCompte() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CuSpacing.xl),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            const SizedBox(height: CuSpacing.lg),
            Center(
              child: Container(
                padding: const EdgeInsets.all(CuSpacing.lg),
                decoration: BoxDecoration(
                  color: CuColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add,
                    size: 48, color: CuColors.primary),
              ),
            ),
            const SizedBox(height: CuSpacing.lg),
            Text(
              'Crée ton compte',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: CuSpacing.sm),
            Text(
              'Tes données seront sauvegardées automatiquement '
              'et liées à ce compte.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CuColors.textSecondaryLight,
                  ),
            ),
            const SizedBox(height: CuSpacing.xl),
            TextFormField(
              controller: _nomCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Ton nom (ou prénom)',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ton nom est requis' : null,
            ),
            const SizedBox(height: CuSpacing.md),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: _validerEmail,
            ),
            const SizedBox(height: CuSpacing.md),
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                helperText: '6 caractères minimum',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                if (v == null || v.length < 6) return '6 caractères minimum';
                return null;
              },
            ),
            const SizedBox(height: CuSpacing.md),
            TextFormField(
              controller: _passConfirmCtrl,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Confirme le mot de passe',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (v) {
                if (v != _passCtrl.text) return 'Les mots de passe ne correspondent pas';
                return null;
              },
            ),
            const SizedBox(height: CuSpacing.lg),
            Container(
              padding: const EdgeInsets.all(CuSpacing.md),
              decoration: BoxDecoration(
                color: CuColors.info.withValues(alpha: 0.08),
                borderRadius: CuRadius.smAll,
                border: Border.all(color: CuColors.info.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 17, color: CuColors.info),
                  const SizedBox(width: CuSpacing.sm),
                  Expanded(
                    child: Text(
                      'L\'app fonctionne sans internet. La sauvegarde '
                      'cloud se fait automatiquement quand tu as du réseau.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: CuColors.info,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CuSpacing.lg),
          ],
        ),
      ),
    );
  }

  String? _validerEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'L\'email est requis';
    final email = v.trim();
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(email)) return 'Format d\'email invalide';
    return null;
  }

  // ─── Page 2 : Thème ─────────────────────────────────────────

  Widget _choixTheme() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(CuSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(CuSpacing.lg),
            decoration: BoxDecoration(
              color: CuColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.palette_outlined,
                size: 72, color: CuColors.primary),
          ),
          const SizedBox(height: CuSpacing.xl),
          Text(
            'Choisis ton apparence',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: CuSpacing.sm),
          Text(
            'Modifiable plus tard depuis les Réglages.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: CuColors.textSecondaryLight,
                ),
          ),
          const SizedBox(height: CuSpacing.x2l),
          ...kThemeModes.map((m) {
            final selected = _themeMode == m;
            final icon = switch (m) {
              'light' => Icons.light_mode,
              'dark' => Icons.dark_mode,
              _ => Icons.brightness_auto,
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: CuSpacing.sm),
              child: GestureDetector(
                onTap: () => setState(() => _themeMode = m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(CuSpacing.lg),
                  decoration: BoxDecoration(
                    color: selected
                        ? CuColors.primary.withValues(alpha: 0.10)
                        : Colors.transparent,
                    borderRadius: CuRadius.mdAll,
                    border: Border.all(
                      color: selected
                          ? CuColors.primary
                          : CuColors.borderLight,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(icon,
                          color: selected ? CuColors.primary : null, size: 22),
                      const SizedBox(width: CuSpacing.md),
                      Expanded(
                        child: Text(
                          themeModeLabel(m),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: selected ? CuColors.primary : null,
                              ),
                        ),
                      ),
                      if (selected)
                        const Icon(Icons.check_circle,
                            color: CuColors.primary, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Page 3 : Conseils ──────────────────────────────────────

  Widget _conseils() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(CuSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(CuSpacing.lg),
              decoration: BoxDecoration(
                color: CuColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.rocket_launch_outlined,
                  size: 72, color: CuColors.primary),
            ),
          ),
          const SizedBox(height: CuSpacing.xl),
          Text(
            'Pour bien démarrer',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: CuSpacing.lg),
          _conseilTile(
            Icons.grid_view,
            '1. Crée tes cages',
            'Onglet "Plus" → Cages. Définis tes bâtiments, '
                'clapiers et cages avec leurs numéros.',
          ),
          _conseilTile(
            Icons.pets,
            '2. Ajoute tes lapins',
            'Onglet "Cheptel" → bouton "+". '
                'Photo facultative, généalogie possible.',
          ),
          _conseilTile(
            Icons.qr_code,
            '3. Utilise les QR codes',
            'Chaque lapin a un QR scannable depuis sa fiche '
                'pour un accès direct au terrain.',
          ),
        ],
      ),
    );
  }

  Widget _conseilTile(IconData icon, String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CuSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(CuSpacing.md),
            decoration: BoxDecoration(
              color: CuColors.primary.withValues(alpha: 0.12),
              borderRadius: CuRadius.smAll,
            ),
            child: Icon(icon, color: CuColors.primary, size: 22),
          ),
          const SizedBox(width: CuSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CuColors.textSecondaryLight,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
