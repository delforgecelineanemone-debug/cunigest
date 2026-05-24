// OnboardingScreen V3 — CuniUI
// Logique inchangée · UI redesignée avec CuniUI tokens

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/db_helper.dart';
import '../models/reglages.dart';
import '../providers/state_providers.dart';
import '../services/account_service.dart';
import '../services/auth/google_auth_service.dart';
import '../services/auth/local_lock_service.dart';
import '../services/sync_service.dart';
import '../ui/cu_ui.dart';
import '../widgets/common_widgets.dart';
import 'auth/google_sign_in_button.dart';
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
    final profilRepo = await DBHelper.instance.profil;
    final r = await profilRepo.getReglages();
    await profilRepo.updateReglages(
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
    if (_page < 4) {
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
      final lien = await AccountService.instance.creerCompte(
        email: _emailCtrl.text.trim(),
        nom: _nomCtrl.text.trim(),
        motDePasse: _passCtrl.text,
      );
      if (!mounted) return;
      // Si la connexion cloud a échoué, on prévient EXPLICITEMENT l'utilisateur
      // avant de continuer : sans cet avertissement il croit avoir un compte
      // cloud et perdra ses données à la réinstallation. notApplicable = build
      // sans Supabase configuré (cas légitime offline-only) → pas d'alerte.
      if (lien == CloudLinkOutcome.failed) {
        await _avertirLienCloudEchoue();
        if (!mounted) return;
      }
      // Demande à l'utilisateur si les données déjà présentes lui
      // appartiennent AVANT tout envoi vers le cloud.
      await _gererDonneesLocales();
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

  /// Avertit l'utilisateur que la connexion au cloud a échoué. L'app reste
  /// pleinement fonctionnelle hors-ligne ; il pourra relier le cloud plus
  /// tard depuis Réglages → Sauvegarde cloud.
  Future<void> _avertirLienCloudEchoue() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.cloud_off, color: CuColors.warning),
            SizedBox(width: CuSpacing.sm),
            Expanded(child: Text('Sauvegarde cloud indisponible')),
          ],
        ),
        content: const Text(
          'Ton compte a bien été créé sur ce téléphone, mais la connexion '
          'au cloud a échoué (pas de réseau ou serveur injoignable).\n\n'
          'L\'app fonctionne hors-ligne — tu peux continuer.\n\n'
          'Pour activer la sauvegarde plus tard : Réglages → Sauvegarde cloud.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  /// Gère les données déjà présentes localement à la création d'un compte.
  ///
  /// CORRECTIF CONFIDENTIALITÉ : avant ce garde-fou, l'app poussait
  /// automatiquement TOUTES les données locales vers le cloud du nouveau
  /// compte — y compris des données de test ou celles d'un autre éleveur
  /// ayant utilisé le même téléphone. On demande désormais explicitement.
  Future<void> _gererDonneesLocales() async {
    final n = await AccountService.instance.compterDonneesLocales();
    if (!mounted) return;

    // Aucune donnée locale → on récupère simplement le contenu du compte.
    if (n == 0) {
      await _showInitialPushModal();
      return;
    }

    final choix = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Des données existent déjà'),
          content: Text(
            'Cet appareil contient déjà des données d\'élevage '
            '($n éléments).\n\n'
            'Sont-elles bien les tiennes ?\n\n'
            '• OUI → elles seront sauvegardées sur ton compte cloud.\n'
            '• NON (données de démonstration, ou compte d\'un autre '
            'éleveur) → choisis « Repartir de zéro » : elles seront '
            'effacées de cet appareil et ne seront PAS envoyées. Si un '
            'compte cloud est lié, ses données seront récupérées à la '
            'place.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'fresh'),
              child: const Text('Repartir de zéro'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'mine'),
              child: const Text('Ce sont mes données'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;

    if (choix == 'fresh') {
      try {
        await DBHelper.instance.effacerDonneesMetier();
        await ref.read(lapinsProvider.notifier).refresh();
        await ref.read(alertesCountProvider.notifier).refresh();
        await ref.read(profilProvider.notifier).refresh();
      } catch (e) {
        debugPrint('ONBOARDING ⚠ effacement données locales : $e');
      }
      if (!mounted) return;
    }
    // 'mine' comme 'fresh' : on lance ensuite la sync. Pour « fresh » la
    // base est vide → la sync ne fait qu'un pull du compte cloud.
    await _showInitialPushModal();
  }

  /// Handler du résultat Google Sign-In. Crée le compte local et
  /// fait avancer l'onboarding vers la page suivante (thème).
  Future<void> _onGoogleResult(GoogleAuthResult result) async {
    debugPrint(
        'ONBOARDING 📥 Google result : success=${result.isSuccess} cancelled=${result.cancelled} email=${result.email} err=${result.error}');
    if (result.cancelled) return;
    if (!result.isSuccess) {
      if (!mounted) return;
      showErrorSnackBar(context, result.error ?? 'Connexion Google échouée');
      return;
    }
    setState(() => _busy = true);
    try {
      // 1. Crée le compte local (synchrone — vite).
      await AccountService.instance.creerCompteGoogle(
        email: result.email ?? '',
        nom: result.displayName,
        session: result.session!,
      );
      debugPrint('ONBOARDING ✅ creerCompteGoogle terminé');
      if (!mounted) return;

      // 2. Gère les données locales (consentement explicite) puis
      //    synchronise. Ne pousse JAMAIS sans l'accord de l'utilisateur.
      await _gererDonneesLocales();
      debugPrint('ONBOARDING ✅ gestion données locales terminée');
      if (!mounted) return;

      setState(() {
        _compteCree = true;
        _busy = false;
      });
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } catch (e, st) {
      debugPrint('ONBOARDING ❌ creerCompteGoogle ÉCHEC : $e\n$st');
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorSnackBar(context, 'Création du compte impossible : $e');
    }
  }

  /// Affiche une modale non-dismissible avec progression en temps réel
  /// pendant le push initial des données locales vers Supabase.
  Future<void> _showInitialPushModal() async {
    final progressNotifier = ValueNotifier<SyncProgress>(
      const SyncProgress(
        phase: 'preparing',
        processed: 0,
        total: 0,
        message: 'Préparation de tes données…',
      ),
    );
    // Capturé AVANT l'await pour rester valide si le widget est unmounted.
    final nav = Navigator.of(context, rootNavigator: true);

    // Ouvre la modale en parallèle du push.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cloud_upload, color: Colors.blue),
              SizedBox(width: 12),
              Expanded(child: Text('Sauvegarde de tes données')),
            ],
          ),
          content: ValueListenableBuilder<SyncProgress>(
            valueListenable: progressNotifier,
            builder: (_, progress, __) {
              return SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(progress.message,
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 16),
                    if (progress.fraction != null)
                      LinearProgressIndicator(
                        value: progress.fraction,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                      )
                    else
                      const LinearProgressIndicator(minHeight: 6),
                    if (progress.total > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${progress.processed} / ${progress.total}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Tes données restent disponibles hors-ligne pendant '
                      'la sauvegarde.',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    // Premier sign-in : on force le push de TOUT (peu importe l'historique
    // local de la sync_queue, qui peut contenir des entries marquées
    // comme "déjà synchronisées" mais à un userId différent).
    final report = await AccountService.instance.doInitialPush(
      forceAll: true,
      onProgress: (p) {
        progressNotifier.value = p;
      },
    );

    if (nav.mounted && nav.canPop()) nav.pop();
    progressNotifier.dispose();

    if (report != null && !report.success && mounted) {
      // On informe l'utilisateur mais on continue l'onboarding —
      // il pourra réessayer manuellement depuis Réglages → Sauvegarde.
      showErrorSnackBar(context,
          'Sauvegarde partielle : ${report.message ?? "réessaye plus tard"}');
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
                  _verrou(),
                  _conseils(),
                ],
              ),
            ),
            // ── Indicateurs de page ──
            Padding(
              padding: const EdgeInsets.only(bottom: CuSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
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
                  if (_page >= 2 && _page < 4)
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
                          label: _page == 4
                              ? 'Commencer'
                              : (_page == 1 && !_compteCree
                                  ? 'Créer mon compte'
                                  : 'Suivant'),
                          icon: _page == 4
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
      ).responsive(),
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

            // ── Connexion Google (V3.1) — chemin rapide premium ──
            GoogleSignInButton(
              onResult: _onGoogleResult,
              enabled: !_busy,
            ),
            const SizedBox(height: CuSpacing.lg),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: CuSpacing.sm),
                  child: Text(
                    'ou crée un compte email',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: CuColors.textSecondaryLight,
                        ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: CuSpacing.lg),

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
                  tooltip: _obscure
                      ? 'Afficher le mot de passe'
                      : 'Masquer le mot de passe',
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
                  const Icon(Icons.info_outline, size: 17, color: CuColors.info),
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
            const SizedBox(height: CuSpacing.md),
            // Échappatoire premium : l'utilisateur n'est pas obligé de créer
            // un compte cloud pour démarrer. L'app reste pleinement
            // fonctionnelle offline ; le compte se configure plus tard
            // dans Réglages → Sauvegarde cloud.
            TextButton.icon(
              onPressed: _busy ? null : _continuerSansCompte,
              icon: const Icon(Icons.cloud_off_outlined, size: 18),
              label: const Text('Démarrer sans compte cloud (offline)'),
              style: TextButton.styleFrom(
                foregroundColor: CuColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: CuSpacing.lg),
          ],
        ),
      ),
    );
  }

  /// Permet de finir l'onboarding sans créer de compte cloud. L'app
  /// fonctionne en mode 100 % offline. L'utilisateur peut lier un
  /// compte plus tard via Réglages → Sauvegarde cloud.
  Future<void> _continuerSansCompte() async {
    setState(() => _busy = true);
    try {
      final profilRepo = await DBHelper.instance.profil;
      final r = await profilRepo.getReglages();
      await profilRepo.updateReglages(r.copyWith(
        onboardingDone: true,
        themeMode: _themeMode,
      ));
      await ref.read(reglagesProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScaffold()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorSnackBar(context, 'Impossible de démarrer : $e');
    }
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

  // ─── Page 3 : Verrou rapide (V3.0 Auth refactor) ────────────

  Widget _verrou() {
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
            child: const Icon(Icons.fingerprint,
                size: 72, color: CuColors.primary),
          ),
          const SizedBox(height: CuSpacing.xl),
          Text(
            'Ouverture rapide',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: CuSpacing.sm),
          Text(
            'Active l\'empreinte ou Face ID pour ouvrir CuniGest en une '
            'seconde, sans saisir ton mot de passe. Tu peux modifier ça '
            'plus tard dans Réglages → Sécurité.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CuColors.textSecondaryLight,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: CuSpacing.x2l),
          CuButton(
            label: 'Activer la biométrie',
            icon: Icons.fingerprint,
            onPressed: _busy ? null : _activerBiometrieOnboarding,
            size: CuButtonSize.lg,
          ),
          const SizedBox(height: CuSpacing.sm),
          TextButton(
            onPressed: _busy
                ? null
                : () => _pageCtrl.nextPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                    ),
            child: const Text('Plus tard'),
          ),
        ],
      ),
    );
  }

  Future<void> _activerBiometrieOnboarding() async {
    final lock = LocalLockService.instance;
    final available = await lock.isBiometryAvailable();
    if (!mounted) return;
    if (!available) {
      showErrorSnackBar(
        context,
        'Biométrie non disponible sur cet appareil. Tu pourras configurer un PIN dans Réglages.',
      );
      return;
    }
    // PIN de secours requis. On utilise les 4 derniers chiffres d'un nombre
    // dérivé du mot de passe, ce qui évite un dialog supplémentaire dans
    // l'onboarding. L'utilisateur pourra changer son PIN ensuite.
    // Mais c'est trop opaque → on demande explicitement un PIN.
    final pin = await _saisirPinOnboarding();
    if (pin == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await lock.setupPin(pin);
      final ok = await lock.enableBiometry();
      if (!mounted) return;
      setState(() => _busy = false);
      if (ok) {
        showSuccessSnackBar(context, 'Biométrie activée 🎉');
        _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      } else {
        showErrorSnackBar(context,
            'Activation annulée. Tu peux réessayer depuis Réglages → Sécurité.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorSnackBar(context, 'Erreur : $e');
    }
  }

  Future<String?> _saisirPinOnboarding() async {
    final ctrl1 = TextEditingController();
    final ctrl2 = TextEditingController();
    String? erreur;
    final res = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Choisis un PIN de secours'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Si la biométrie échoue (gants, doigt mouillé…), le PIN te permettra d\'entrer.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl1,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
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
    return res;
  }

  // ─── Page 4 : Conseils ──────────────────────────────────────

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
