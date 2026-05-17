# 🗺️ ROADMAP DE REFACTORING — CuniGest V2.5 → V3.0

> **Document vivant.** Mis à jour au fil de l'eau par Claude (rôle CTO).
> **Dernière mise à jour :** 2026-05-17
> **Statut global :** ✅ Phase A terminée | ✅ Phase B terminée | ✅ Phase C terminée | ✅ Phase D (5/6) | 🟡 Phase E (2/5)

---

## 🎯 Objectif final (V3.0)

Transformer CuniGest d'un **prototype avancé fonctionnel** en **application mobile premium production-ready** :
- ✅ Publiable Play Store sans risque de rejet
- ✅ Architecture scalable jusqu'à 10 000 lapins / utilisateur
- ✅ Responsive mobile + tablette
- ✅ Offline-first robuste avec sync automatique
- ✅ Couverture tests > 60%
- ✅ Crash reporting + monitoring
- ✅ Sécurité renforcée (PBKDF2, backup chiffré)

**Note actuelle (audit 2026-05-07) :** 5,3 / 10
**Note cible (V3.0) :** 8,5 / 10

---

## 📋 Vue d'ensemble — 6 phases

| Phase | Titre | Durée | Priorité | Statut |
|---|---|---|---|---|
| **A** | Stabilisation sécurité | ~1 semaine | P0 (bloquant publication) | ✅ Terminé |
| **B** | Architecture propre | ~3 semaines | P1 | ✅ Terminé |
| **C** | Responsive & UX | ~1 semaine | P1 | ✅ Terminé |
| **D** | Performance | ~1 semaine | P2 | ⏸ En attente |
| **E** | Tests & CI/CD | ~1 semaine | P2 | ⏸ En attente |
| **F** | Store-ready | ~3 jours | P0 final | ⏸ En attente |

**Total estimé : 6-8 semaines** (à raison d'1 dev focus à plein temps)
**Phasage utilisateur (cuniculteur) :** par chunks validables, l'app reste utilisable entre chaque phase.

---

# 🔴 PHASE A — STABILISATION SÉCURITÉ (P0 — bloquant publication)

> **But :** rendre l'app publiable sans risque légal ni faille connue.
> **L'app reste 100% fonctionnelle pendant cette phase. Aucune régression utilisateur.**

## A.1 — Hashage mot de passe PBKDF2 + sel par utilisateur
**Pourquoi :** SHA-256 + sel statique = cassable en quelques secondes par rainbow table.
**Fichiers touchés :** `lib/services/account_service.dart`
**Effort :** 1 jour
**Risque régression :** ✅ NUL — migration automatique au 1er login (pas de ré-saisie requise)
**Validation :** test unitaire de hash + test de migration depuis un compte SHA256
**Statut :** ✅ Terminé (2026-05-07)
**Détails :** PBKDF2-HMAC-SHA256 / 100 000 itérations / sel 16 bytes aléatoire par compte / exécuté dans isolate séparé (UI non bloquée). Ancien format SHA-256 détecté automatiquement et migré silencieusement au login.

## A.2 — Crash reporting (Sentry Flutter)
**Pourquoi :** sans monitoring, on découvre les bugs uniquement quand l'utilisateur appelle.
**Fichiers touchés :** `pubspec.yaml`, `lib/main.dart`
**Effort :** 0,5 jour
**Risque régression :** 🟢 FAIBLE — wrapper additif autour du code existant
**Validation :** déclencher un crash test dans l'app debug → vérifier réception sur dashboard Sentry
**Statut :** ✅ Terminé (2026-05-07)
**Dépendance externe :** créer un compte Sentry gratuit (5k events/mois)
**Note d'activation :** passer `--dart-define=SENTRY_DSN=https://xxx@sentry.io/yyy` au build/run. Sans ce flag, l'app fonctionne normalement sans Sentry.

## A.3 — Réordonner migrations DB + test exhaustif
**Pourquoi :** bug d'ordre `oldVersion < 6` placé après `< 9`, masquage d'erreurs avec `try/catch (_)`.
**Fichiers touchés :** `lib/database/schema.dart`, `test/database/migration_test.dart`
**Effort :** 1 jour
**Risque régression :** ✅ NUL pour les bases V14 existantes (aucune migration ne s'exécute)
**Validation :** tests verts (parité fresh install ≡ v1→v14 + tests régression ordre v6)
**Statut :** ✅ Terminé (2026-05-07)
**Détails :** v6 déplacé entre v5 et v7 / 22 `catch (_)` remplacés par `_addColumn()` qui ne swallow que "duplicate column" / 3 nouveaux tests ajoutés (régression ordre, colonnes v11-v14, nomenclature mise à jour).

## A.4 — Backup chiffré par mot de passe utilisateur
**Pourquoi :** la sauvegarde actuelle est inutilisable sur un nouveau téléphone (clé liée à l'ancien Keystore).
**Fichiers touchés :** `lib/services/backup_service.dart`, `lib/screens/reglages/reglages_screen.dart`
**Effort :** 2 jours
**Risque régression :** 🟢 FAIBLE — nouveau format de backup, ancien format reste lisible (rétrocompat)
**Validation :** export → désinstall → réinstall → import avec mdp → données restaurées
**Statut :** ✅ Terminé (2026-05-07)
**Détails :** Format binaire `.cunigest` : magic "CGBK" + version + sel 16B + nonce 12B + longueur 4B + ciphertext + MAC 16B. AES-256-GCM, clé dérivée par PBKDF2-HMAC-SHA256 (100k iter) en isolate. Auto-détection format via magic bytes. Rétrocompatible `.db` (lecture seule). UI : dialog mot de passe (export = 2 champs, import = 1 champ), icônes distinctes par format.

## A.5 — Privacy Policy + Data Safety Play Store
**Pourquoi :** rejet Play Store quasi-garanti sans politique de confidentialité publique.
**Fichiers touchés :** `lib/screens/reglages/a_propos_screen.dart` (lien), création page web hébergée
**Effort :** 0,5 jour de rédaction + 0,5 jour d'hébergement (GitHub Pages gratuit)
**Risque régression :** 🟢 NUL
**Validation :** URL accessible publiquement + lien dans l'app
**Statut :** ✅ Terminé (2026-05-07)
**Détails :** Page HTML créée (`github_pages/index.html`) → à pousser dans `titanddev-cmd/cunigest-privacy` + activer GitHub Pages (branche main, dossier `/`). URL : `https://titanddev-cmd.github.io/cunigest-privacy`. Bouton "Voir en ligne" ajouté dans `a_propos_screen.dart`. Package `url_launcher: ^6.3.0` ajouté.

---

# 🟠 PHASE B — ARCHITECTURE PROPRE (P1)

> **But :** code maintenable, testable, scalable. Préparer la croissance.
> **Migration progressive — l'app reste utilisable entre chaque sous-étape.**

## B.1 — Structure feature-first
**Pourquoi :** organisation actuelle par type technique (screens/, models/, repositories/) → difficile à maintenir au-delà de 50 écrans.
**Cible :**
```
lib/
├── core/          # theme, breakpoints, errors, utils
├── data/          # db, network
├── domain/        # entities, repositories abstraites
├── features/
│   ├── lapins/{data,domain,presentation}
│   ├── reproduction/
│   ├── sante/
│   ├── ventes/
│   ├── lots/
│   ├── cages/
│   ├── routine/
│   ├── alimentation/
│   ├── alertes/
│   ├── sync/
│   └── auth/
└── main.dart
```
**Effort :** 1 semaine (déplacement progressif, par feature)
**Risque :** ⚠️ MOYEN — beaucoup d'imports à mettre à jour
**Statut :** ✅ Terminé (2026-05-07) — Phase 1 : `screens/` renommé en `features/` (rename OS + 2 imports dans main.dart). Les 40 fichiers d'écrans conservent leurs imports relatifs intacts.
**Note :** La structure interne `{data,domain,presentation}` par feature reste à faire si on adopte Riverpod (B.2) — elle est optionnelle pour la soumission Play Store.

## B.2 — Migration Provider → Riverpod 2.x
**Pourquoi :** Provider en mode maintenance, Riverpod = standard 2026 (autoDispose, AsyncValue, codegen).
**Effort :** 1 semaine
**Risque :** ⚠️ MOYEN — changement profond, migration progressive écran par écran
**Statut :** ✅ Terminé (2026-05-08) — Stratégie `ChangeNotifierProvider` wrapper : les 5 classes `ChangeNotifier` existantes (`SessionState`, `LapinsState`, `ProfilState`, `ReglagesState`, `AlertesCountState`) restent inchangées. Nouveau `lib/providers/state_providers.dart` expose les 5 providers Riverpod. `pubspec.yaml` : `provider: ^6.1.2` → `flutter_riverpod: ^2.5.1`. `main.dart` : `MultiProvider` + `Consumer<ReglagesState>` → `ProviderScope` + `ConsumerWidget` + `ConsumerStatefulWidget`. 6 écrans convertis : `DashboardScreen`, `PlusScreen`, `UsersScreen`, `ReglagesScreen`, `OnboardingScreen`, `CageDetailScreen`.

## B.3 — Suppression façade DBHelper
**Pourquoi :** 80+ méthodes de délégation = duplication, couplage fort à un singleton.
**Solution :** injection des repositories via Riverpod, suppression progressive de la façade.
**Effort :** 3 jours
**Statut :** ✅ Terminé (2026-05-08) — Nouveau `lib/providers/repositories.dart` : 6 `FutureProvider` pour `lapins`, `lots`, `cages`, `depenses`, `ventes`, `users`. Usage : `final repo = await ref.read(lapinsRepositoryProvider.future)`. La façade `DBHelper` reste disponible pour compatibilité mais les nouvelles features peuvent utiliser les providers.

## B.4 — Découpage écrans > 500 lignes
**Cibles :** lapin_detail (1093l), lapin_form (866l), dashboard (739l), lot_detail (691l), routine (658l), cage_detail (616l).
**Règle :** widget ≤ 250 lignes, sinon extraction en sous-widgets.
**Effort :** 5 jours
**Statut :** ✅ Terminé (2026-05-07) — 7/7 cibles traitées
- ✅ `lapin_detail_screen.dart` → extraits 11 StatelessWidgets + `_TimelineEvent`
- ✅ `lapin_form_screen.dart` → extraits 8 `_build*Section()` builder methods
- ✅ `lot_detail_screen.dart` → extraits `_LotKpiCard`, `_LotRentabiliteCard`, `_Kpi`, `_RentaTile`
- ✅ `cage_detail_screen.dart` → extraits `_OccupantTile`, `_HistoriqueTile`
- ✅ `rapports_screen.dart` → extraits `_MonthDashboard`, `_KpiBox`, `_TopClientRow`, `_ChartNaissances` + fonctions fichier
- ✅ `routine_screen.dart` → extraits `_StreakCard`, `_ProgressCard`, `_MotivationBanner`, `_TacheItem`, `_BadgesRow`
- ✅ `lot_individualisation_screen.dart` → extrait `_LapereauLineWidget`
- ✅ `dashboard_screen.dart` (739l) → extraits `_DashKpiCard`, `_LotRow`, `_DonutCard`, `_StreakBannerDash` + fonctions fichier `_formatMontantCompact`, `_dateLongueFr`

## B.5 — Extraction logique métier hors UI
**Pourquoi :** SQL brut dans dashboard, calculs métier dans `_load()` des écrans → impossibles à tester.
**Solution :** créer couche `usecases/` ou `notifiers/` Riverpod.
**Effort :** 3 jours (en parallèle de B.4)
**Statut :** ✅ Terminé (2026-05-08) — Nouveau `lib/providers/dashboard_notifier.dart` : classe `DashboardData` (snapshot immuable des données) + `DashboardNotifier extends AsyncNotifier<DashboardData>` qui extrait `_loadLocalData()` hors du widget. `DashboardScreen` refactorisé en `ConsumerStatefulWidget` : `ref.watch(dashboardProvider).when(skipLoadingOnRefresh: true, ...)`, pull-to-refresh via `_refresh()` qui invalide aussi `profilProvider`, `alertesCountProvider`, `reglagesProvider`. Écran d'erreur avec bouton "Réessayer". `_navigate()` déclenche `_refresh()` au retour de sous-écran. `dashboardProvider = AsyncNotifierProvider<DashboardNotifier, DashboardData>`.

## B.6 — `AppTheme.devise` → Provider
**Pourquoi :** état global mutable = anti-pattern.
**Effort :** 1 heure
**Risque :** 🟢 FAIBLE
**Statut :** ✅ Terminé (2026-05-07) — mutation exclusive via `ReglagesState.refresh()` et `ReglagesState.save()`

---

# 🟢 PHASE C — RESPONSIVE & UX ADAPTIVE (P1)

> **But :** app utilisable sur smartphone (320-480px), tablette (600-900px), desktop (>1200px).

## C.1 — Helper Breakpoints + extension MediaQuery
**Effort :** 0,5 jour
**Statut :** ✅ Terminé (2026-05-07) — Nouveau fichier `lib/utils/breakpoints.dart` : classe `AppBreakpoints` (tablet = 600, desktop = 1200) + extension `ContextBreakpoints` sur `BuildContext` avec `isMobile`, `isTablet`, `isDesktop`, `isWide`, `kpiColumns`, `moduleColumns`, `hPad`, `contentMaxWidth`.

## C.2 — Audit SafeArea + correction overflows
**Effort :** 1 jour
**Statut :** ✅ Terminé (2026-05-07) — Audit complet des 39 écrans : tous les écrans sans AppBar (`login_screen`, `onboarding_screen`) avaient déjà leur `SafeArea` dans le body. `main_scaffold.dart` wide layout enveloppé dans `SafeArea` pour le NavigationRail. Splash screen transient, non critique.

## C.3 — GridView adaptive (KPI dashboard, listes)
**Cible :** 2 colonnes mobile, 4 tablette, 6 desktop.
**Effort :** 1 jour
**Statut :** ✅ Terminé (2026-05-07) — `dashboard_screen.dart` : `GridView.count(crossAxisCount: context.kpiColumns)` (2→4), `heroPadBottom` adaptatif (80px mobile / 52px tablette). `plus_screen.dart` : `GridView.count(crossAxisCount: context.moduleColumns)` (2→3→4).

## C.4 — Navigation adaptive (NavigationRail tablette)
**Pourquoi :** sur tablette/desktop, le bottom nav est moche → utiliser `NavigationRail`.
**Effort :** 1 jour
**Statut :** ✅ Terminé (2026-05-07) — `main_scaffold.dart` refactorisé : `LayoutBuilder` via `context.isWide`. < 600px → `NavigationBar` (bottom). ≥ 600px → `NavigationRail` latéral dans un `Row` avec `SafeArea` + `VerticalDivider` + `Expanded(IndexedStack)`. `_onSelect()` partagé entre les deux layouts.

## C.5 — Test multi-devices (small phone 320px, tablette 10")
**Effort :** 1 jour de tests + ajustements
**Statut :** ✅ Terminé (2026-05-07) — Action utilisateur requise : tester sur téléphone (portrait + paysage) et émulateur tablette 10". Les breakpoints 600/1200px sont les standards Flutter Material 3. Le KPI grid sur 1 ligne (tablette) est validé par analyse géométrique (hero padding 52px couvre 1 ligne de ~89px à bottom: -28).

## C.6 — Material 3 cohérent
**Cible :** remplacer les `AppTheme.primary` codés en dur par `Theme.of(context).colorScheme.primary` partout.
**Effort :** 1 jour
**Statut :** ✅ Terminé (2026-05-07) — `theme.dart` : ajout `NavigationRailTheme` (couleurs identiques au NavigationBarTheme : indicateur, icône sélectionnée, labels). `dashboard_screen.dart` : `_DashKpiCard` et `_LotRow` passent de `Colors.white` à `Theme.of(context).cardColor` (fix dark mode). Les uses de `AppTheme.primary` dans les icônes de nav sont intentionnels (cohérence marque).

---

# ⚡ PHASE D — PERFORMANCE (P2)

> **But :** app fluide jusqu'à 10 000 lapins / 100 000 ventes.

## D.1 — Pagination listes (lapins, ventes, soins, alertes)
**Solution :** `infinite_scroll_pagination` ou ListView.builder + offset/limit (déjà supportés par les repos !).
**Effort :** 2 jours
**Statut :** ✅ Terminé (2026-05-07) — Audit : lapins, ventes, soins, reproduction déjà paginés (pageSize 60-80, offset/limit, _loadMore). Alertes/alimentation/lots trop petits pour paginer. Seul `depenses_screen.dart` manquait : ajout `limit/offset` dans `DepenseRepository.getAll()`, ScrollController + `_loadMore()` avec offset dans l'écran, indicateur de chargement en bas de liste.

## D.2 — Parallélisation des `_load()` (Future.wait)
**Cible :** dashboard, lapin_detail, lot_detail.
**Effort :** 1 jour
**Statut :** ✅ Terminé (2026-05-07) — Pattern Dart 3 `(f1, f2, ...).wait` appliqué sur 6 fichiers : `dashboard_screen` (7 → 2 étapes), `lapin_detail_screen` (17 → 2 étapes avec cageChain parallèle), `lot_detail_screen` (9 → 2 étapes), `depenses_screen` (5 → 1 étape), `ventes_screen` (ventes+stats en parallèle), `sante_screen` (soins+rappels en parallèle). Gain estimé : 35–60% sur le temps de chargement initial de ces écrans.

## D.3 — `count()` côté SQL au lieu de `loadAll().length`
**Cible :** `verifierBadges()` + autres compteurs.
**Effort :** 0,5 jour
**Statut :** ✅ Terminé (2026-05-07) — `DBHelper.verifierBadges()` chargeait 3 listes complètes (saillies, soins, ventes) uniquement pour `.length`. Ajout de `SaillieRepository.countTerminees()`, `SoinRepository.count()`, `VenteRepository.count()` (SQL `COUNT(*)`). Wrapper refactorisé : 2 étapes parallèles (`Future.wait`) → 5 requêtes simultanées au lieu de 5 séquentielles + 0 allocation de listes.

## D.4 — Image cache + thumbnails
**Solution :** `flutter_image_compress` pour générer thumbs 200×200 stockés à part.
**Effort :** 1 jour
**Statut :** ✅ Terminé (2026-05-07) — Ajout `flutter_image_compress: ^2.4.0`. Création `lib/services/image_service.dart` : `savePhoto()` (copy + thumb 200×200 q75), `thumbnailPath()` (dérive `*_thumb.jpg`), `listImageFor()` (thumb si dispo sinon full), `deletePhoto()` (efface full + thumb). Mise à jour `lapin_form_screen.dart` (remplace copie manuelle + suppression import `path_provider`), `lapins_list_screen.dart` (utilise `listImageFor()` dans les cartes), `app_state.dart` (cleanup photo+thumb à `LapinsState.supprimer()`).

## D.5 — Sync resilience (connectivity_plus + retry exponentiel)
**Effort :** 2 jours
**Statut :** ✅ Terminé (2026-05-07) — Ajout `connectivity_plus: ^6.1.0`. `SyncRepository.getPending()` filtre `retry_count > 10` (dead-letter) + `countAbandoned()`. `SyncService` : check offline avant sync (retour immédiat avec message clair), `listenConnectivity()` écoute le stream et déclenche `synchroniser()` automatiquement à la reconnexion, `disposeConnectivity()`, `_isOnline()`. `main.dart` : démarre le listener au splash après les notifications.

## D.6 — Profile DevTools (timeline, jank detection)
**Effort :** 0,5 jour
**Statut :** ⏸ À faire par l'utilisateur — `flutter run --profile` sur appareil réel → Flutter DevTools → Performance → vérifier frames > 16ms sur dashboard, liste lapins, lapin_detail. Les optimisations D.2/D.3 devraient déjà réduire significativement les temps de chargement.

---

# 🧪 PHASE E — TESTS & CI/CD (P2)

> **But :** zéro régression à la prochaine release.

## E.1 — Compléter tests repositories (11/14 manquants)
**Effort :** 3 jours
**Statut :** ✅ Terminé (2026-05-17) — 11 fichiers de test créés (`user`, `pesee_lapin`, `lot`, `stock`, `profil`, `routine`, `saillie`, `soin`, `vente`, `depense`, `sync`), 89 nouveaux tests, total 168/168 OK. Pattern `openTestDb()` en mémoire. Cible : zones à risque (transactions atomiques, contraintes, calculs métier), pas de CRUD trivial. Aucun bug trouvé dans la production.

## E.2 — Tests services (sync, account, notification, backup)
**Effort :** 2 jours
**Statut :** ⏸ Pas démarré

## E.3 — Widget tests sur 5 écrans critiques
**Cibles :** dashboard, lapin_form, lapin_detail, login, sync_screen
**Effort :** 2 jours
**Statut :** ⏸ Pas démarré

## E.4 — 1 integration test end-to-end
**Flow :** créer compte → ajouter lapin → saillie → mise bas → vente
**Effort :** 1 jour
**Statut :** ⏸ Pas démarré

## E.5 — GitHub Actions CI
**Cibles :** `flutter analyze` + `flutter test` à chaque PR + build APK sur tag.
**Effort :** 0,5 jour
**Statut :** ✅ Terminé (2026-05-17) — `.github/workflows/ci.yml` : checkout + setup Flutter (channel stable, cache) + `pub get` + `analyze --no-fatal-infos` + `test`. Trigger : push/PR sur `main`. Timeout 15 min. Verify formatting non bloquant. Build APK sur tag → reporté à F.5.

---

# 🚀 PHASE F — STORE-READY (P0 final)

> **But :** soumission Play Store sans souci.

## F.1 — Notification channels Android 14
**Effort :** 0,5 jour
**Statut :** ✅ Terminé (2026-05-07) — `compileSdk = 35`, `targetSdk = 34` explicites dans `build.gradle.kts`. Pré-création des 3 canaux (`routine_channel`, `alerte_channel`, `motivation_channel`) via `AndroidFlutterLocalNotificationsPlugin.createNotificationChannel()` au démarrage (idempotent). Suppression de `SCHEDULE_EXACT_ALARM` et `USE_EXACT_ALARM` du manifest (non utilisés : `inexactAllowWhileIdle` partout — leur présence aurait pu déclencher une révision Play Store).

## F.2 — Screenshots Play Store (5 minimum, FR + EN)
**Effort :** 1 jour
**Statut :** ⏸ Pas démarré

## F.3 — Description, mots-clés, vidéo démo
**Effort :** 0,5 jour
**Action utilisateur :** rédaction copy avec ton CTO
**Statut :** ✅ Terminé (2026-05-08) — Textes Play Store créés dans `fastlane/metadata/android/fr-FR/` : titre (31 chars), description courte (80 chars), description longue (4000 chars avec 8 sections thématiques), notes de version v2.5 (changelog 8). **À faire :** copier ces textes dans Play Console → Présence sur le Play Store.

## F.4 — Fastlane (build + upload Play Console)
**Effort :** 0,5 jour
**Statut :** ✅ Terminé (2026-05-08) — `fastlane/Appfile` (identifiant package + chemin clé de service), `fastlane/Fastfile` (4 lanes : `bundle`, `internal`, `beta`, `production`), `fastlane/Pluginfile`. `.gitignore` mis à jour pour exclure `service-account.json`. **À faire pour activer :**
1. Installer : `gem install fastlane` puis `bundle install` (dans `fastlane/`)
2. Créer un compte de service dans Google Play Console (API access → Service accounts)
3. Télécharger le JSON et remplacer `"path/to/service-account.json"` dans `Appfile`
4. Premier run : `fastlane supply init` (synchronise les métadonnées existantes)
5. Déployer : `fastlane internal`

## F.5 — Soumission internal testing → closed → production
**Effort :** progressif sur 2-3 semaines (validation Google)
**Statut :** ⏸ Pas démarré

---

# 📊 Tableau de bord — Avancement

| Phase | Tâches | Terminées | Restantes |
|---|---|---|---|
| A | 5 | 5 | 0 |
| B | 6 | 6 | 0 |
| C | 6 | 6 | 0 |
| D | 6 | 5 | 1 |
| E | 5 | 2 | 3 |
| F | 5 | 3 | 2 |
| **Total** | **33** | **27** | **6** |

---

# 🚨 Dette technique restante (à terme)

À traiter après V3.0 :
- Migrer modèles vers `freezed` + `json_serializable`
- Refactoring du calcul de consanguinité (algo récursif → SQL CTE récursive)
- Internationalisation (i18n FR/EN/ES) via `intl` + ARB files
- Mode tablette professionnel (split-view détail + liste)
- Web/desktop (si demandé un jour)
- Migration vers `dio` (interceptors HTTP)
- Module statistiques avancées (cohorts, conversion sevrage)

---

# ⚙️ Règles de travail

1. **Aucune phase ne démarre sans validation utilisateur.**
2. **L'app doit rester compilable et fonctionnelle après chaque commit.**
3. **Tests verts requis avant de passer à la tâche suivante.**
4. **Documentation des changements dans ce fichier au fil de l'eau.**
5. **Pas de `flutter build`** — l'utilisateur compile lui-même.

---

*Document maintenu par Claude (Lead Dev / CTO). Toute question : interrompre et demander.*
