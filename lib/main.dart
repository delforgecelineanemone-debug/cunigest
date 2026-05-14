// ──────────────────────────────────────────────────────────────
// CuniGest — Point d'entrée de l'application (V2.5)
// ──────────────────────────────────────────────────────────────
// 1. Initialise Sentry si SENTRY_DSN fourni (--dart-define)
// 2. Initialise la base de données + migrations
// 3. Initialise les notifications (timezone système)
// 4. Wrap l'app avec ProviderScope (Riverpod state management)
// 5. Si des utilisateurs existent → écran de login PIN
//    Sinon → mode "solo legacy" (pas de login)
// 6. Gestion d'erreur globale (FlutterError + runZonedGuarded)
// ──────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'providers/state_providers.dart';
import 'utils/theme.dart';
import 'features/onboarding_screen.dart';
import 'features/auth/login_screen.dart';
import 'database/db_helper.dart';
import 'services/account_service.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';
import 'services/error_logger_service.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await ErrorLoggerService.instance.init();

      // Sentry activé uniquement si le DSN est fourni :
      //   flutter run --dart-define=SENTRY_DSN=https://xxx@sentry.io/yyy
      const sentryDsn = String.fromEnvironment('SENTRY_DSN');
      if (sentryDsn.isNotEmpty) {
        await SentryFlutter.init((options) {
          options.dsn = sentryDsn;
          options.release = 'gestion_cunicole@2.5.0+8';
          options.environment = const String.fromEnvironment(
            'SENTRY_ENV',
            defaultValue: 'production',
          );
          options.tracesSampleRate = 0.0; // pas de perf-tracing pour économiser le quota
        });
      }

      // Logger local chaîné avec Sentry (si initialisé ci-dessus).
      // On sauvegarde le handler courant (Sentry ou Flutter défaut) avant d'override.
      final previousFlutterHandler = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        debugPrint('[FlutterError] ${details.exceptionAsString()}');
        debugPrint(details.stack.toString());
        ErrorLoggerService.instance.log(
          'FlutterError',
          details.exceptionAsString(),
          details.stack,
        );
        previousFlutterHandler?.call(details);
      };

      runApp(const ProviderScope(child: CuniGestApp()));
    },
    (error, stack) {
      debugPrint('[Uncaught Error] $error');
      debugPrint(stack.toString());
      Sentry.captureException(error, stackTrace: stack);
      ErrorLoggerService.instance.log('UncaughtError', error, stack);
    },
  );
}

class CuniGestApp extends ConsumerWidget {
  const CuniGestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reglages = ref.watch(reglagesProvider);
    final r = reglages.reglages;
    AppTheme.devise = r.devise;

    // Mode soleil force le thème clair pour la lisibilité en plein soleil.
    final mode = r.modeSoleil
        ? ThemeMode.light
        : switch (r.themeMode) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          };

    // Mode gants agrandit les cibles tactiles à 56 dp (vs 48 dp standard).
    final theme = r.modeGants
        ? AppTheme.theme.copyWith(
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: AppTheme.theme.elevatedButtonTheme.style?.copyWith(
                minimumSize: const WidgetStatePropertyAll(Size(64, 56)),
                padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: AppTheme.theme.filledButtonTheme.style?.copyWith(
                minimumSize: const WidgetStatePropertyAll(Size(64, 56)),
              ),
            ),
            iconButtonTheme: IconButtonThemeData(
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(56, 56)),
                iconSize: const WidgetStatePropertyAll(28),
              ),
            ),
          )
        : AppTheme.theme;

    return MaterialApp(
      title: 'CuniGest',
      theme: theme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      debugShowCheckedModeBanner: false,
      // Mode soleil : +25 % sur la taille du texte pour la lisibilité extérieure.
      builder: r.modeSoleil
          ? (ctx, child) {
              final mq = MediaQuery.of(ctx);
              final boosted = (mq.textScaler.scale(1.0) * 1.25).clamp(1.1, 2.0);
              return MediaQuery(
                data: mq.copyWith(textScaler: TextScaler.linear(boosted)),
                child: child!,
              );
            }
          : null,
      home: const SplashScreen(),
    );
  }
}

/// Écran d'accueil affiché pendant 2.5s au lancement.
/// Initialise la DB et les notifications, puis route vers le bon écran :
///   - Login si des utilisateurs existent
///   - MainScaffold (bottom nav 5 onglets) sinon
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    _initApp();
  }

  String _initStatus = 'Initialisation…';

  Future<void> _initApp() async {
    // Chaque étape est isolée pour qu'une erreur ne bloque pas la suivante.
    // Les erreurs sont logguées via debugPrint et affichées dans le splash.

    try {
      _setStatus('Base de données…');
      await DBHelper.instance.database
          .timeout(const Duration(seconds: 25));
      debugPrint('SPLASH ✅ DB ouverte');

      try {
        await DBHelper.instance.genererAlertesReproduction();
        await DBHelper.instance.nettoyerAlertes();
      } catch (e) {
        debugPrint('SPLASH ⚠ alertes : $e');
      }
    } catch (e, st) {
      debugPrint('SPLASH ❌ DB : $e\n$st');
      _setStatus('Une erreur est survenue. Redémarre l\'app.');
      // Re-tente la navigation après 3s pour pas bloquer définitivement
      await Future.delayed(const Duration(seconds: 3));
    }

    try {
      _setStatus('Notifications…');
      await NotificationService.instance
          .init()
          .timeout(const Duration(seconds: 8));
      await NotificationService.instance.programmerToutes();
      debugPrint('SPLASH ✅ notifs');
    } catch (e) {
      debugPrint('SPLASH ⚠ notifs : $e');
    }

    try {
      SyncService.instance.listenConnectivity();
      debugPrint('SPLASH ✅ connectivity listener');
    } catch (e) {
      debugPrint('SPLASH ⚠ connectivity : $e');
    }

    try {
      _setStatus('Chargement des données…');
      if (mounted) {
        // Capture les notifiers AVANT les awaits pour éviter
        // l'usage de BuildContext après async gap.
        final lapins = ref.read(lapinsProvider.notifier);
        final profil = ref.read(profilProvider.notifier);
        final reglages = ref.read(reglagesProvider.notifier);
        final alertes = ref.read(alertesCountProvider.notifier);
        await lapins.refresh();
        await profil.refresh();
        await reglages.refresh();
        await alertes.refresh();
      }
    } catch (e) {
      debugPrint('SPLASH ⚠ state : $e');
    }

    // Routage V2.6 — compte cuniculteur unique :
    //   - Pas de compte local créé    → Onboarding (création obligatoire)
    //   - Compte créé                 → Login (mot de passe)
    //   - (le mode "solo legacy" sans compte est supprimé)
    bool compteExiste = false;
    try {
      compteExiste = await AccountService.instance.compteExiste();
    } catch (e) {
      debugPrint('SPLASH ⚠ compte check : $e');
    }
    // Marqueur secondaire (legacy) : ancien flag d'onboarding
    bool onboardingDone = true;
    try {
      final r = await DBHelper.instance.getReglages();
      onboardingDone = r.onboardingDone;
    } catch (_) {/* ignore */}

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final Widget destination;
    if (!compteExiste) {
      destination = const OnboardingScreen();
    } else if (!onboardingDone) {
      // Compte présent mais onboarding pas terminé (cas rare : quitté en cours)
      destination = const OnboardingScreen();
    } else {
      destination = const LoginScreen();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _setStatus(String s) {
    if (mounted) setState(() => _initStatus = s);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1D9E75),
              Color(0xFF0F7A5A),
              Color(0xFF0A5C43),
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(255, 255, 255, 0.2),
                        borderRadius: BorderRadius.circular(35),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.2),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('🐇', style: TextStyle(fontSize: 64)),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'CuniGest',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'V2 — Gestion cunicole pro',
                      style: TextStyle(
                        color: Color.fromRGBO(255, 255, 255, 0.8),
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 48),
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _initStatus,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color.fromRGBO(255, 255, 255, 0.85),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
