# Changelog

Toutes les modifications notables de ce projet sont documentées dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/),
et ce projet adhère au [Semantic Versioning](https://semver.org/lang/fr/).

---

## [2.5] - 2026-05

### Ajouté
- **Supabase V3.1** — initialisation offline-first avec timeout 8 s, flux PKCE, gestion de session persistante
- **Google Sign-In** — connexion OAuth en un tap, compte Google lié au profil local
- **Realtime multi-appareils** — WebSocket Supabase pour que les données apparaissent en live sur plusieurs téléphones
- **Sync résiliente V17-V19** — colonnes `updated_at` / `deleted_at` (soft-delete) sur toutes les tables miroirs ; backoff exponentiel (`next_retry_at`) sur la `sync_queue` ; `enqueueAllExistingRows()` pour push initial
- **Barre de progression sync** — modale temps réel `SyncProgress` pendant les push/pull longs
- **Formulaire lapin en wizard 3 étapes** — réduit la surcharge cognitive (Identité → Généalogie → Santé)
- **Notifier `LapinDetailNotifier`** — fiche lapin pilotée par `AsyncNotifierProvider.family`, plus de `setState` brut
- **`EncryptionKeyLostException`** — détecte la corruption du secure storage sans écraser la clé (fichier marqueur)
- **Écran de récupération de clé** — guide l'éleveur en cas de clé introuvable
- **Filtre PII Sentry** — emails, téléphones et noms masqués avant envoi (`_scrubSentryEvent`)
- **`KpiService`** — tracking événements produit (sync réussie/échouée) pour le monitoring
- **Certificate pinning** — vérifie l'empreinte TLS avant sync (protection MITM Wi-Fi)
- **`DataBus`** — bus d'événements pub/sub inter-composants (remplace les callbacks manuels)
- **Guard confidentialité onboarding** — demande explicitement si les données locales appartiennent à l'éleveur avant tout push cloud
- **`FCFA` devise par défaut** — remplace `€` (DB schema V19 + migration automatique)

### Amélioré
- **Migration Riverpod** — `ChangeNotifierProvider` → `NotifierProvider` avec `ViewState` immuables (`SessionViewState`, `LapinsViewState`, `ProfilViewState`)
- **`_UnfocusNavigatorObserver`** — résout le crash « dirty InputDecorator in wrong build scope » à chaque changement de route
- **Anti double-tap formulaire** — overlay `CuFormScaffold.markSaving()` bloque les soumissions multiples
- **`_busy` sync cohérent** — flag maintenu pendant toute la durée de la modale de progression
- **Navigation sécurisée post-async** — référence `NavigatorState` capturée avant les `await` longs
- **`markSaved()` garanti** — bloc `finally` dans `_save()` retire toujours l'overlay même si `!mounted`
- **Log rows sans id** — `enqueueAllExistingRows` journalise les lignes ignorées
- **`unawaited()` explicite** — remplace les suppressions de lint `// ignore: discarded_futures`
- **Tests backoff** — 4 cas couvrant cooldown, expiration, croissance stricte des délais
- **Tests soft-delete** — vérification que `deleteStock` soft-delete et préserve les consommations
- **Wizard formulaire lapin** — viewport de test agrandi pour les 3 étapes
- **`FakeLapinDetailNotifier`** — les widget tests de `LapinDetailScreen` n'ont plus besoin d'une vraie DB

### Corrigé
- Crash « Tried to build dirty widget in the wrong build scope » sur pop/push de formulaire
- `ValueNotifier` correctement disposé après fermeture des modales de sync
- Texte dialogue « Repartir de zéro » mentionne désormais le pull cloud associé

### Supprimé
- `LoginScreen` remplacé par le nouveau flux d'auth (lock screen + Google)
- `AppState` (`lib/state/app_state.dart`) — remplacé par les `NotifierProvider` Riverpod
- Tests `login_screen_test.dart` (écran supprimé)

---

## [2.4] - 2026-05

### Ajouté
- Audit complet de l'interface utilisateur (UI) — v3.1
- Landing page publique pour la présentation du projet
- Déploiement automatisé via GitHub Pages

### Amélioré
- Cohérence visuelle sur l'ensemble des écrans
- Documentation du projet (README, CONTRIBUTING, templates GitHub)

---

## [2.3] - 2026-04

### Ajouté
- Navigation inférieure avec 5 onglets principaux
- Mode sombre (dark mode) complet
- Écrans d'onboarding pour les nouveaux utilisateurs
- Courbes et graphiques interactifs via `fl_chart`
- États vides (empty states) illustrés sur toutes les listes

### Amélioré
- Expérience utilisateur générale et fluidité de la navigation
- Performance d'affichage des listes de données

---

## [2.2]

### Ajouté
- Module Cages complet avec hiérarchie : Bâtiments → Clapiers → Cages
- Upload et affichage de photos pour les lapins
- Génération de QR codes pour l'identification des cages
- Génération d'étiquettes PDF imprimables pour les cages

### Amélioré
- Organisation et gestion de l'infrastructure d'élevage

---

## [2.1]

### Ajouté
- Chiffrement de la base de données locale avec AES-256
- Gestion fine des permissions Android

### Corrigé
- Stabilisation générale de l'application
- Correction de bugs critiques identifiés en production
- Amélioration de la fiabilité des opérations de données

---

## [2.0]

### Ajouté
- Module Lots d'engraissement complet
- Calcul du Gain Moyen Quotidien (GMQ) et de l'Indice de Consommation (IC)
- Synchronisation cloud via Supabase
- Système multi-utilisateur avec authentification par PIN
- Génération de rapports PDF détaillés
- Système de QR codes pour le suivi des animaux

### Amélioré
- Architecture de l'application pour le support multi-utilisateur
- Performance de synchronisation des données

---

## [1.0]

### Ajouté
- Gestion complète des lapins (fiches individuelles, identification)
- Module de reproduction (accouplements, gestations, mises bas, portées)
- Module de santé (traitements, vaccinations, suivi sanitaire)
- Module d'alimentation (rations, stocks, consommation)
- Module de ventes (enregistrement, suivi des revenus)
- Système de notifications et rappels automatiques
- Base de données locale SQLite

---

[2.5]: https://github.com/delforgecelineanemone-debug/cunigest/compare/v2.4...v2.5
[2.4]: https://github.com/delforgecelineanemone-debug/cunigest/compare/v2.3...v2.4
[2.3]: https://github.com/delforgecelineanemone-debug/cunigest/compare/v2.2...v2.3
[2.2]: https://github.com/delforgecelineanemone-debug/cunigest/compare/v2.1...v2.2
[2.1]: https://github.com/delforgecelineanemone-debug/cunigest/compare/v2.0...v2.1
[2.0]: https://github.com/delforgecelineanemone-debug/cunigest/compare/v1.0...v2.0
[1.0]: https://github.com/delforgecelineanemone-debug/cunigest/releases/tag/v1.0
