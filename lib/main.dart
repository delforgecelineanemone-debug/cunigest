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
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/state_providers.dart';
import 'utils/app_config.dart';
import 'utils/theme.dart';
import 'features/onboarding_screen.dart';
import 'features/auth/lock_screen.dart';
import 'features/auth/key_recovery_screen.dart';
import 'features/main_scaffold.dart';
import 'database/db_helper.dart';
import 'services/encryption_key_service.dart';
import 'services/account_service.dart';
import 'services/auth/cloud_auth_service.dart';
import 'services/auth/local_lock_service.dart';
import 'services/auth/session_manager.dart';
import 'services/notification_service.dart';
import 'services/realtime_service.dart';
import 'services/sync_service.dart';
import 'services/error_logger_service.dart';
import 'services/kpi_service.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await ErrorLoggerService.instance.init();
      await KpiService.instance.init();

      // Init Supabase (V3.1) — Auth + Realtime + persistence session.
      // Le client gère automatiquement le refresh des tokens et la
      // persistance via SharedPreferences (par défaut).
      // Si SUPABASE_URL/ANON_KEY ne sont pas fournis, on saute l'init :
      // l'app reste fonctionnelle offline-only.
      if (AppConfig.hasSupabaseDefaults) {
        try {
          debugPrint('Supabase ⏳ init en cours…');
          await Supabase.initialize(
            url: AppConfig.supabaseUrl,
            anonKey: AppConfig.supabaseAnonKey,
            authOptions: const FlutterAuthClientOptions(
              authFlowType: AuthFlowType.pkce,
            ),
            // Pas de Realtime activé par défaut — c'est l'app qui s'abonne
            // explicitement aux channels qui l'intéressent (cf. Phase 4).
            realtimeClientOptions: const RealtimeClientOptions(
              logLevel: RealtimeLogLevel.warn,
            ),
          ).timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              debugPrint(
                  'Supabase ⏱ init timeout 8s — l\'app continue offline');
              throw TimeoutException('Supabase init timeout');
            },
          );
          debugPrint('Supabase ✅ initialisé');

          // Sync automatique des tokens dans sync_config dès qu'une
          // session est créée ou rafraîchie par supabase_flutter.
          // Permet au SyncService legacy (push/pull REST) de toujours
          // avoir des tokens valides sans réécriture.
          Supabase.instance.client.auth.onAuthStateChange.listen((data) {
            final s = data.session;
            if (s != null) {
              // Fire-and-forget intentionnel dans un listener synchrone :
              // la mise à jour des tokens est best-effort, une éventuelle
              // erreur n'est pas bloquante (la prochaine authStateChange
              // réessaiera).
              unawaited(AccountService.instance.syncFromSupabaseSession(s));
            }
          });

          // Realtime : démarre l'écoute WebSocket dès qu'une session
          // est disponible (et la stoppe au signOut). Multi-device =
          // tes données apparaissent en live sur les autres téléphones.
          RealtimeService.instance.wireUp();
        } catch (e, st) {
          debugPrint('Supabase ⚠ init échec : $e\n$st');
          // L'app reste démarrable même si Supabase plante — offline-first.
        }
      } else {
        debugPrint('Supabase ⚠ SUPABASE_URL absent — mode offline-only');
      }

      // Sentry activé uniquement si le DSN est fourni :
      //   flutter run --dart-define=SENTRY_DSN=https://xxx@sentry.io/yyy
      // Le DSN a une defaultValue dans AppConfig : les builds release
      // remontent toujours les crashs même sans --dart-define explicite.
      const sentryDsn = AppConfig.sentryDsn;
      if (sentryDsn.isNotEmpty) {
        await SentryFlutter.init((options) {
          options.dsn = sentryDsn;
          options.release = 'gestion_cunicole@2.5.0+8';
          options.environment = AppConfig.sentryEnv;
          options.tracesSampleRate = 0.0; // pas de perf-tracing pour économiser le quota
          // PII filter — on retire emails, tokens, noms d'éleveur, noms de
          // lapins, contenu de notes avant envoi. Sentry n'a besoin que
          // de la stack trace et du type d'erreur pour être utile.
          options.sendDefaultPii = false;
          options.beforeSend = (event, hint) async {
            return _scrubSentryEvent(event);
          };
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

/// Filtre les données personnelles avant envoi à Sentry.
///
/// Stratégie : on supprime tout ce qui pourrait identifier l'éleveur ou
/// ses animaux dans le contexte de l'erreur. Les stack traces et les types
/// d'exception restent intacts — c'est suffisant pour débugger.
///
/// Champs scrubbés :
///   - User : id, ip, email, username, nom complet
///   - Request : headers (cookies, auth), URL paramètres (token)
///   - Contexts : tout `email`, `bague`, `notes`, `password`, `token`
///   - Extra/Tags : idem
SentryEvent? _scrubSentryEvent(SentryEvent event) {
  // 1. Coupe l'utilisateur (Sentry remplit auto par défaut)
  final scrubbed = event.copyWith(user: null);

  // 2. Masque les messages d'exception qui contiendraient des emails
  //    ou des données identifiantes (regex simple, suffisante en pratique).
  final emailRegex = RegExp(r'\b[\w.+-]+@[\w-]+\.[\w.-]+\b');
  final phoneRegex = RegExp(r'\b\+?\d[\d \-.]{7,}\b');
  String scrubText(String? s) {
    if (s == null) return '';
    return s
        .replaceAll(emailRegex, '[email]')
        .replaceAll(phoneRegex, '[phone]');
  }

  return scrubbed.copyWith(
    message: event.message == null
        ? null
        : SentryMessage(
            scrubText(event.message!.formatted),
            template: event.message!.template,
            params: event.message!.params,
          ),
  );
}

/// Observer de navigation qui libère le focus clavier à chaque
/// transition de route (push/pop/replace).
///
/// Sans ça, un `TextField` encore focalisé au moment où sa route est
/// dépilée peut être désactivé alors qu'il est « dirty », ce qui
/// corrompt l'arbre de widgets : `Tried to build dirty widget in the
/// wrong build scope` → écran rouge / crash. Très visible lors des
/// confirmations (dialogues) et des retours arrière sur formulaires.
class _UnfocusNavigatorObserver extends NavigatorObserver {
  void _unfocus() {
    final f = FocusManager.instance.primaryFocus;
    if (f != null && f.hasFocus) f.unfocus();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _unfocus();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _unfocus();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _unfocus();
}

/// Instance unique partagée (l'identité doit rester stable entre les
/// rebuilds de MaterialApp).
final unfocusNavigatorObserver = _UnfocusNavigatorObserver();

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
            iconButtonTheme: const IconButtonThemeData(
              style: ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size(56, 56)),
                iconSize: WidgetStatePropertyAll(28),
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
      // Libère le focus clavier à chaque changement de route — évite le
      // crash "dirty InputDecorator in wrong build scope" provoqué par un
      // champ de saisie encore focalisé désactivé pendant un pop/push.
      navigatorObservers: [unfocusNavigatorObserver],
      // Le builder wrap chaque route avec :
      //   1. Mode soleil (textScaler +25 % si activé)
      //   2. AuthGate (overlay LockScreen quand la session est verrouillée)
      builder: (ctx, child) {
        Widget wrapped = child!;
        if (r.modeSoleil) {
          final mq = MediaQuery.of(ctx);
          final boosted = (mq.textScaler.scale(1.0) * 1.25).clamp(1.1, 2.0);
          wrapped = MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(boosted)),
            child: wrapped,
          );
        }
        return _AuthGate(child: wrapped);
      },
      home: const SplashScreen(),
    );
  }
}

/// Superpose le LockScreen sur toute l'app dès que la session
/// passe en `locked` (retour foreground après délai dépassé).
///
/// Au démarrage (status == unknown), n'affiche rien : le splash et
/// le routage initial gèrent le 1er affichage du verrou.
class _AuthGate extends ConsumerWidget {
  const _AuthGate({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionManagerProvider);
    // Le splash et le routage initial s'occupent déjà du premier verrou.
    // Cet overlay ne s'active que pour les re-locks après foreground.
    final showLock = session.isLocked && !_isInitialBoot(child);
    return Stack(
      children: [
        child,
        if (showLock)
          const Positioned.fill(
            child: Material(child: LockScreen(fromBoot: false)),
          ),
      ],
    );
  }

  /// Heuristique : pendant le boot (SplashScreen affichée), on ne
  /// superpose pas — le splash gère le routage initial vers
  /// LockScreen ou MainScaffold.
  bool _isInitialBoot(Widget child) {
    // child est toujours un Navigator englobant les routes ; on
    // utilise un flag statique mis à jour par SplashScreen.
    return !_AuthGateState.bootCompleted;
  }
}

/// État partagé pour signaler la fin du splash.
abstract class _AuthGateState {
  static bool bootCompleted = false;
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
    // ─── Phase 1 : DB (bloquant, sans elle rien ne fonctionne) ──
    // Timeout 8s (réduit de 25s) — si la DB met plus de 8s à s'ouvrir,
    // on a un vrai problème (corruption, secure_storage cassé) et l'utilisateur
    // doit redémarrer plutôt que d'attendre indéfiniment.
    try {
      _setStatus('Base de données…');
      await DBHelper.instance.database
          .timeout(const Duration(seconds: 8));
      debugPrint('SPLASH ✅ DB ouverte');
    } on EncryptionKeyLostException catch (e, st) {
      // Clé de chiffrement perdue (secure storage corrompu) : on NE
      // réinitialise PAS en silence — écran de récupération dédié.
      debugPrint('SPLASH 🔐 clé perdue : $e\n$st');
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const KeyRecoveryScreen()),
      );
      return;
    } catch (e, st) {
      debugPrint('SPLASH ❌ DB : $e\n$st');
      _setStatus('Erreur base de données — redémarre l\'application.');
      // Pas de continuation : la DB est indispensable. On laisse l'écran
      // d'erreur affiché jusqu'à ce que l'utilisateur ferme l'app.
      return;
    }

    // ─── Phase 2 : tout le reste en parallèle (8s max par tâche) ──
    // Tous les init non-critiques s'exécutent en parallèle pour minimiser
    // le temps de splash. Une erreur sur un init n'empêche pas les autres
    // de finir — l'app reste démarrable.
    _setStatus('Chargement des données…');

    // Capture les notifiers AVANT les awaits parallèles : on ne peut pas
    // utiliser ref/context après un async gap si l'écran s'est démonté.
    final lapinsNotifier =
        mounted ? ref.read(lapinsProvider.notifier) : null;
    final profilNotifier =
        mounted ? ref.read(profilProvider.notifier) : null;
    final reglagesNotifier =
        mounted ? ref.read(reglagesProvider.notifier) : null;
    final alertesNotifier =
        mounted ? ref.read(alertesCountProvider.notifier) : null;

    Future<void> safe(String label, Future<void> Function() task,
        {Duration timeout = const Duration(seconds: 8)}) async {
      try {
        await task().timeout(timeout, onTimeout: () {
          debugPrint('SPLASH ⏱ $label timeout');
        });
        debugPrint('SPLASH ✅ $label');
      } catch (e) {
        debugPrint('SPLASH ⚠ $label : $e');
      }
    }

    await Future.wait<void>([
      safe('alertes', () async {
        await DBHelper.instance.genererAlertesReproduction();
        await (await DBHelper.instance.alertes).nettoyerAlertes();
      }),
      safe('notifs', () async {
        await NotificationService.instance.init();
        await NotificationService.instance.programmerToutes();
      }),
      safe('connectivity', () async {
        SyncService.instance.listenConnectivity();
        SyncService.instance.wireAutoPush();
      }, timeout: const Duration(seconds: 2)),
      safe('state', () async {
        await lapinsNotifier?.refresh();
        await profilNotifier?.refresh();
        await reglagesNotifier?.refresh();
        await alertesNotifier?.refresh();
      }),
    ]);

    // Refresh proactif silencieux du token Supabase — fire-and-forget,
    // ne bloque jamais le splash. L'app reste utilisable même si ça échoue.
    // ignore: discarded_futures
    CloudAuthService.instance.proactiveRefresh().then((h) {
      debugPrint('SPLASH ☁ cloud health = ${h.name}');
    });

    // ─── Routage V3.0 — Auth refactor ──────────────────────────
    // Le mot de passe cloud n'est PLUS demandé à chaque ouverture.
    // Logique :
    //   - Pas de compte local créé        → Onboarding
    //   - Compte + verrou local actif     → LockScreen (PIN ou biométrie)
    //   - Compte + aucun verrou (défaut)  → MainScaffold direct ⚡
    //
    // Le SessionManager est initialisé pour observer le cycle de vie.
    bool compteExiste = false;
    try {
      compteExiste = await AccountService.instance.compteExiste();
    } catch (e) {
      debugPrint('SPLASH ⚠ compte check : $e');
    }

    // ─── Récupération auto du compte local depuis Supabase ──
    // Cas : l'utilisateur a fait Google Sign-In mais le compte local
    // n'a jamais été persisté (app fermée trop tôt, erreur silencieuse).
    // Si Supabase a une session valide, on recrée le compte local
    // automatiquement à partir de la session — pas besoin de re-signin.
    //
    // Timeout 3s pour ne JAMAIS bloquer le splash : si quelque chose
    // tourne en boucle, on continue vers l'onboarding plutôt que de
    // laisser l'utilisateur planté sur le splash.
    if (!compteExiste) {
      try {
        await Future(() async {
          final supabase = Supabase.instance.client;
          final session = supabase.auth.currentSession;
          final user = supabase.auth.currentUser;
          if (session != null && user != null && !session.isExpired) {
            final email = user.email ?? '';
            final nom = user.userMetadata?['full_name'] as String? ??
                user.userMetadata?['name'] as String?;
            debugPrint(
                'SPLASH 🔄 récupération compte depuis session Supabase ($email)');
            await AccountService.instance.creerCompteGoogle(
              email: email,
              nom: nom,
              session: session,
            );
            compteExiste = await AccountService.instance.compteExiste();
            debugPrint(
                'SPLASH ✅ compte récupéré : compteExiste=$compteExiste');
          } else {
            debugPrint(
                'SPLASH ℹ pas de session Supabase valide à récupérer');
          }
        }).timeout(const Duration(seconds: 3), onTimeout: () {
          debugPrint('SPLASH ⏱ récup compte timeout 3s — on continue');
        });
      } catch (e, st) {
        debugPrint('SPLASH ⚠ récup compte Supabase : $e\n$st');
      }
    }

    bool onboardingDone = true;
    try {
      final r = await (await DBHelper.instance.profil).getReglages();
      onboardingDone = r.onboardingDone;
    } catch (_) {/* ignore */}

    LockMode lockMode = LockMode.none;
    try {
      await SessionManager.instance.evaluateInitial();
      lockMode = await LocalLockService.instance.currentMode();
    } catch (e) {
      debugPrint('SPLASH ⚠ lock mode : $e');
    }

    // Petit délai cosmétique pour que l'animation du logo se termine sans
    // brusquer la transition. Pas indispensable mais améliore le ressenti.
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // Routage tolérant V3.2 :
    // - Onboarding fini (compte cloud OU mode offline-only) → MainScaffold
    //   ou LockScreen selon `lockMode`.
    // - Aucun signal → OnboardingScreen.
    // Un utilisateur qui a choisi « Démarrer sans compte cloud » a
    // `onboardingDone = true` sans `compteExiste` → l'app reste utilisable.
    debugPrint(
        'SPLASH 🚦 compteExiste=$compteExiste onboardingDone=$onboardingDone lockMode=${lockMode.name}');
    final Widget destination;
    if (!compteExiste && !onboardingDone) {
      destination = const OnboardingScreen();
    } else if (lockMode == LockMode.none) {
      // Pas de verrou local : ouverture directe, comme WhatsApp/Notion.
      destination = const MainScaffold();
    } else {
      destination = const LockScreen();
    }
    // Active l'AuthGate pour les re-locks après foreground.
    _AuthGateState.bootCompleted = true;

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
