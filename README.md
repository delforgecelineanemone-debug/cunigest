# 🐇 CuniGest

[![CI](https://github.com/delforgecelineanemone-debug/cunigest/actions/workflows/ci.yml/badge.svg)](https://github.com/delforgecelineanemone-debug/cunigest/actions/workflows/ci.yml)
[![GitHub Pages](https://github.com/delforgecelineanemone-debug/cunigest/actions/workflows/deploy-pages.yml/badge.svg)](https://github.com/delforgecelineanemone-debug/cunigest/actions/workflows/deploy-pages.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-jade.svg)](./LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-stable-blue.svg)](https://flutter.dev)

**Le cahier d'élevage cunicole, sur mobile.**

Application mobile professionnelle pour les éleveurs de lapins en Afrique.
Cheptel, reproduction, santé, ventes — hors-ligne par défaut, synchronisation cloud optionnelle, FCFA, modes gants & soleil.

🌐 **[Voir la landing page →](https://delforgecelineanemone-debug.github.io/cunigest/)**

---

## ✨ Fonctionnalités principales

| Module | Description |
|--------|-------------|
| 🐇 **Cheptel** | Fiches individuelles, photo, race, généalogie 3 générations, détection de consanguinité |
| 💜 **Reproduction** | Saillies, palpation J+10, mise bas J+31, sevrage — compte-à-rebours visuel par portée |
| 🩺 **Santé** | Vaccins, traitements, délais d'attente médicamenteux avec blocage de vente automatique |
| 📊 **Lots & engraissement** | Pesées, distributions, GMQ et indice de consommation automatiques |
| 💰 **Ventes & dépenses** | Chiffre d'affaires, marge, clients récurrents — FCFA, € ou $ |
| 🏠 **Cages & QR** | Bâtiments → Clapiers → Cages, étiquettes PDF QR 8/page, scanner unifié |
| 🧤 **Mode gants** | Cibles tactiles 56 dp, pour les mains gantées au clapier |
| ☀️ **Mode soleil** | Typo +25 %, thème clair forcé, lisible en plein soleil |
| ⚡ **Routine & gamification** | Streak, niveaux, badges — la motivation au quotidien |
| ☁️ **Sync cloud** | Supabase optionnel, multi-appareils, rôles admin/soigneur |

---

## 🔒 Hors-ligne d'abord

- **100 % fonctionnel sans connexion** — SQLite chiffré AES-256 sur l'appareil
- **Synchronisation optionnelle** — Supabase, stratégie last-write-wins
- **Sauvegarde locale chiffrée** — Export `.cunigest` AES-256-GCM, partageable par WhatsApp/mail/USB
- **Multi-appareils** — Compte partagé admin + soigneurs, RLS Postgres côté serveur

---

## 🛠️ Stack technique

| Couche | Technologie |
|--------|-------------|
| Langage | Dart 3 / Flutter (Material 3) |
| State | Riverpod / Provider 6.x |
| Base | sqflite_sqlcipher (SQLite chiffré AES-256) |
| Stockage clés | flutter_secure_storage (Android Keystore) |
| Photos | image_picker + path_provider |
| Notifications | flutter_local_notifications + timezone |
| QR | qr_flutter + mobile_scanner |
| PDF | pdf + printing |
| Sync cloud | http (Supabase REST) |
| Auth locale | crypto (PIN SHA-256) |

---

## 🚀 Installation

### Prérequis

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable)
- [Android Studio](https://developer.android.com/studio) avec SDK Command-line Tools
- Un appareil Android ou émulateur (minSdk 21)

### Démarrage rapide

```bash
# 1. Cloner le dépôt
git clone https://github.com/delforgecelineanemone-debug/cunigest.git
cd cunigest

# 2. Installer les dépendances
flutter pub get

# 3. Lancer en mode debug (téléphone branché USB)
# Utiliser le script fourni :
./build_debug.bat

# 4. Compiler l'APK release
./build_release.bat
```

> ⚠️ **Important** : Utilisez les scripts `.bat` fournis pour les builds.
> Ils passent la configuration Supabase via `--dart-define`.
> Un `flutter build apk` direct désactivera la synchronisation cloud.

---

## 🧪 Tests

```bash
flutter test
```

Couvre : gamification, délais d'attente, mortalité, sync, validations.

---

## 📁 Structure du projet

```
lib/
├── main.dart                    # Entry point + providers
├── database/                    # SQLite + migrations
├── features/                    # Écrans par module
│   ├── auth/                    # Authentification PIN/cloud
│   ├── dashboard_screen.dart    # Tableau de bord KPIs
│   ├── lapins/                  # Cheptel
│   ├── reproduction/            # Saillies, portées
│   ├── sante/                   # Soins, vaccins
│   ├── cages/                   # Bâtiments/Clapiers/Cages
│   ├── lots/                    # Engraissement
│   ├── ventes/                  # Ventes & dépenses
│   ├── alimentation/            # Stocks aliment
│   ├── routine/                 # Tâches quotidiennes
│   ├── rapports/                # PDF export
│   ├── qr/                      # Scanner/génération QR
│   └── sync/                    # Synchronisation cloud
├── models/                      # Modèles de données
├── providers/                   # State management
├── repositories/                # Couche d'accès données
├── services/                    # Logique métier
├── ui/                          # Design system (tokens, atoms, molecules)
└── utils/                       # Utilitaires
```

---

## 🔐 Modèle de permissions

| Action | Admin | Soigneur | Solo |
|--------|-------|----------|------|
| Voir/créer lapins, saillies, soins | ✅ | ✅ | ✅ |
| Voir/créer ventes & rapports PDF | ✅ | ❌ | ✅ |
| Réglages, utilisateurs, sync cloud | ✅ | ❌ | ✅ |
| Supprimer | ✅ | ❌ | ✅ |

---

## 🗺️ Roadmap

- ✅ **V2.0** — Lots, GMQ/IC, sync Supabase, multi-utilisateur, QR codes, PDF
- ✅ **V2.1** — Stabilisation, chiffrement DB, permissions Android
- ✅ **V2.2** — Module Cages complet, photos lapins
- ✅ **V2.3** — Bottom nav 5 onglets, dark mode, onboarding, courbes croissance
- ✅ **V2.4** — Audit UX/UI V3.1, landing page, GitHub Pages
- 🟦 **V3.0** — Tâches avancées, coût production, pedigree PDF 4 générations, export CSV
- 🟦 **V3.1** — Play Store (signing, RGPD, crash reporting, fiche store)

---

## 🤝 Contribuer

Les contributions sont les bienvenues ! Consultez [CONTRIBUTING.md](./CONTRIBUTING.md) pour les guidelines.

---

## 📄 Licence

Ce projet est sous licence [MIT](./LICENSE).

---

## 📬 Contact

- **Email** : [titanddev@gmail.com](mailto:titanddev@gmail.com)
- **GitHub** : [@delforgecelineanemone-debug](https://github.com/delforgecelineanemone-debug)

---

<p align="center">
  <em>Conçu avec soin pour les éleveurs africains 🌍</em>
</p>
