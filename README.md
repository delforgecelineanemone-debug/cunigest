# 🐇 CuniGest — Application de gestion cunicole (V2.3)

Application mobile Android développée en Flutter pour la gestion professionnelle d'un élevage de lapins.
Fonctionne **100 % hors-ligne** par défaut, avec synchronisation cloud optionnelle (Supabase).

> 📜 **Cahier des charges V2** : voir [`Cahier des Charges V2.md`](./Cahier%20des%20Charges%20V2.md)
> 📜 **Cahier des charges V1.5** : voir [`Cahier des Charges V1.5.md`](./Cahier%20des%20Charges%20V1.5.md)

---

## 🆕 Nouveautés V2.3 (Phase 3 — Refonte UX complète)

- **Bottom navigation 5 onglets** : Tableau / Cheptel / Repro / Santé / Plus
- **Dashboard recentré** : KPIs + bannières d'alerte (sans grille de modules redondante)
- **Onglet "Plus"** : Cages, Lots, Aliment, Ventes, Rapports, Stats, Routine, Scanner QR, Sync, Utilisateurs, Réglages
- **🌙 Mode sombre** : automatique (système) / clair / sombre — choix dans Réglages
- **👋 Onboarding** au premier lancement : bienvenue, choix du thème, conseils de démarrage
- **📈 Courbes de croissance** (`fl_chart`) sur la fiche lot — poids moyen dans le temps avec tooltip tactile
- **🎨 Empty states** repensés : icônes cerclées colorées, messages clairs, hints, CTA avec icône
- **Polish Material 3** : NavigationBar M3, ChipTheme, DividerTheme cohérents en clair/sombre

## Nouveautés V2.2 (Phase 2 — module Cages)

- **Hiérarchie complète** : Bâtiments → Clapiers → Cages (numéros libres type "C4B1")
- **Capacité** : chaque cage a une capacité maximale définie par l'éleveur (1 à N lapins)
- **Statuts riches** : `vide`, `occupée`, `gestante`, `allaitement`, `sevrage`, `quarantaine`, `désinfection`, `maintenance`
- **Historique des déplacements** : chaque mouvement de lapin (entrée/sortie/déplacement) est tracé avec date, motif et notes
- **Sélecteur de cage** dans la fiche lapin (vue groupée bâtiment → clapier → cage avec capacité dispo)
- **Photos lapins** *(facultatives)* : prise photo ou import galerie, stockage local
- **QR cages scannables** : chaque cage a son propre QR code (`cunigest:cage:<id>:<numero>`)
- **Étiquettes PDF** : impression d'étiquettes A4 (8 par page) avec QR pour collage sur les cages
- **Auto-toggle de statut** : passage `vide` ↔ `occupée` automatique lors d'un déplacement
- **Scanner unifié** : le scanner QR ouvre directement la fiche lapin OU la fiche cage selon le code

## 🚀 Fonctionnalités V2

### 🐇 Élevage
- **Lapins** : Fiches individuelles (bague unique), recherche, **généalogie** père/mère, **photo facultative**
- **Reproduction** : Saillies, J+31 auto, **détection de consanguinité**, statistiques (fertilité, prolificité, mortalité)
- **Lots d'engraissement** *(NOUVEAU)* : pesées, distributions d'aliment, **GMQ** (Gain Moyen Quotidien) + **IC** (Indice de Consommation)
- **Santé** : Soins/vaccinations, rappels, **délai d'attente médicament** avec blocage de vente
- **Alimentation** : Stocks, consommations, alertes seuil bas
- **Ventes** : Individuelles ou par lots, suivi du chiffre d'affaires

### 🏠 Cages *(V2.2)*
- **Bâtiments / Clapiers / Cages** hiérarchique
- **Vue grille** par clapier (3 colonnes, badge couleur statut)
- **Statistiques** : total cages, occupées, total lapins
- **Fiche cage** : occupants, déplacements, QR, étiquette imprimable

### 📊 Outils pro
- **QR codes** *(NOUVEAU)* : génération par lapin ET par cage (impression) + scanner caméra unifié
- **Rapports PDF** *(NOUVEAU)* : mensuel et bilan annuel (aperçu, partage, impression)
- **Étiquettes cages PDF** *(V2.2)* : 8 étiquettes A4 par page avec QR scannable
- **Statistiques reproduction** : fertilité, prolificité, mortalité naissance et pré-sevrage
- **Sauvegarde / Restauration** : Export local + partage cloud/mail

### 👥 Multi-utilisateur *(NOUVEAU)*
- Authentification PIN locale (4-6 chiffres)
- Rôles : **admin** (accès complet) / **soigneur** (saisie quotidienne sans finances)
- Mode solo possible (pas d'authentification)

### ☁️ Synchronisation cloud *(NOUVEAU)*
- Backend Supabase (REST)
- Push automatique des modifications locales (sync_queue)
- Configuration via UI (URL + anon-key)
- Stratégie : last-write-wins

### 🔔 Routines & Notifications
- Streak avec tolérance configurable, badges, niveaux (gamification désactivable)
- Tâches hebdo/mensuel visibles toute la période
- Heures de notifications configurables, fuseau horaire système auto

---

## 🛠️ Installation pour débutant (Windows)

### Étape 1 : Installer Flutter
1. https://docs.flutter.dev/get-started/install/windows/mobile
2. Décompresser le SDK dans `C:\flutter`
3. Ajouter `C:\flutter\bin` au Path Windows
4. Vérifier : `flutter --version`

### Étape 2 : Installer Android Studio
1. https://developer.android.com/studio
2. SDK Manager → SDK Tools → cocher **Android SDK Command-line Tools**
3. Accepter les licences : `flutter doctor --android-licenses`

### Étape 3 : Configuration Android (V2.1)

Les permissions sont **déjà déclarées** dans `android/app/src/main/AndroidManifest.xml` :
- `CAMERA` — scanner QR (`mobile_scanner`) + photos lapins (Phase 2, `image_picker`)
- `INTERNET`, `ACCESS_NETWORK_STATE` — sync cloud Supabase optionnelle
- `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE` — alertes locales

Vérifier dans `android/app/build.gradle` que `minSdkVersion = 21` est bien présent.

### Étape 4 : Récupérer les dépendances
```bash
cd C:\Users\GUIFO\Desktop\dev\cunicole_app
flutter pub get
```

### Étape 5 : Générer les fichiers natifs (premier lancement uniquement)
```bash
flutter create .
```

### Étape 6 : Lancer en mode développement (téléphone branché USB)
**Double-cliquez sur `build_debug.bat`** à la racine du projet.

Le script lance `flutter run` avec la config Supabase déjà incluse.

### Étape 7 : Compiler l'APK final pour installer sur téléphone
**Double-cliquez sur `build_release.bat`** à la racine du projet.

Le script génère l'APK avec la config Supabase. Sortie :
`build\app\outputs\flutter-apk\app-release.apk`

> ⚠️ **Important** : NE LANCEZ PAS `flutter build apk --release` directement.
> Sans le passage de la config Supabase via `--dart-define`, la
> synchronisation cloud sera désactivée dans l'APK.

---

## ☁️ Configuration Supabase (synchronisation cloud)

Le projet est **déjà configuré** : URL et clé sont dans les scripts
`build_release.bat` / `build_debug.bat`. Tu n'as rien à faire de plus.

### Pour utiliser la sync dans l'app
1. Réglages → ☁️ Synchronisation cloud
2. Bouton **« Activer la sync »** (mode anonyme — pas d'email à saisir)
3. C'est tout. Tes données partent vers le cloud et sont récupérables en cas de réinstall.

### Pour synchroniser entre 2 téléphones (optionnel)
Bouton « Options avancées » → créer un compte avec email + mot de passe,
puis se connecter avec le même compte sur l'autre téléphone.

### Si tu veux tout refaire depuis zéro (admin)
- Projet Supabase : `psqjcgdzauwsdplxgdjn`
- Auth → Providers : activer **« Allow anonymous sign-ins »**
- 8 tables miroirs côté serveur : lapins, saillies, soins, ventes, stocks,
  lots, pesees, distributions_aliment — chacune avec `user_id uuid`,
  `updated_at timestamptz default now()`, `deleted_at timestamptz`,
  PK composite `(user_id, id)`, RLS activée avec policies
  `auth.uid() = user_id` (select/insert/update/delete).

---

## 🧪 Lancer les tests

```bash
flutter test
```

Couvre : niveaux gamification, délais d'attente, mortalité pré-sevrage, âge des lapins.

---

## 💻 Stack technique V2

| Couche | Technologie |
|---|---|
| Langage | Dart 3 / Flutter (Material 3) |
| State management | provider 6.x |
| Base | sqflite_sqlcipher (SQLite v7 chiffré AES-256) |
| Stockage clés | flutter_secure_storage (Android Keystore) |
| Photos | image_picker + path_provider |
| Notifications | flutter_local_notifications + timezone + flutter_timezone |
| Sauvegarde | path_provider + share_plus + file_picker |
| QR | qr_flutter + mobile_scanner |
| PDF | pdf + printing |
| Sync cloud | http (Supabase REST) |
| Auth locale | crypto (PIN SHA-256) |

---

## 📁 Structure du projet

```
lib/
├── main.dart                          # Splash + MultiProvider + routing
├── database/
│   └── db_helper.dart                 # Connection + migrations v1→v5 + facade
├── repositories/                       # 🆕 V2
│   ├── lot_repository.dart            # Lots + GMQ + IC
│   ├── sync_repository.dart           # File sync cloud
│   ├── user_repository.dart           # Multi-utilisateur PIN
│   └── cage_repository.dart           # 🆕 V2.2 — Bâtiments/Clapiers/Cages + déplacements
├── state/                              # 🆕 V2
│   └── app_state.dart                 # ChangeNotifiers Provider
├── services/
│   ├── notification_service.dart      # TZ système + alertes
│   ├── backup_service.dart            # Export/restore DB
│   ├── pdf_service.dart               # 🆕 V2 — Rapports PDF
│   └── sync_service.dart              # 🆕 V2 — Sync Supabase
├── models/
│   ├── lapin.dart, saillie.dart, soin.dart, vente.dart
│   ├── stock.dart, tache.dart, alerte.dart, profil.dart, reglages.dart
│   ├── lot.dart                       # 🆕 V2
│   ├── user.dart                      # 🆕 V2
│   ├── sync_entry.dart                # 🆕 V2
│   ├── batiment.dart                  # 🆕 V2.2
│   ├── clapier.dart                   # 🆕 V2.2
│   ├── cage.dart                      # 🆕 V2.2
│   └── mouvement_cage.dart            # 🆕 V2.2 — historique déplacements
├── screens/
│   ├── home_screen.dart               # ⚡ Migré vers Provider
│   ├── auth/                          # 🆕 V2
│   │   ├── login_screen.dart
│   │   └── users_screen.dart
│   ├── lots/                          # 🆕 V2
│   ├── qr/                            # 🆕 V2 (scanner unifié lapin+cage)
│   ├── rapports/                      # 🆕 V2
│   ├── sync/                          # 🆕 V2
│   ├── cages/                         # 🆕 V2.2 — home, fiche cage, formulaires
│   ├── lapins/, reproduction/, sante/, ventes/, alimentation/, routine/, alertes/, reglages/
└── utils/, widgets/
```

---

## 🔐 Modèle de permissions

| Action | Admin | Soigneur | Solo |
|---|---|---|---|
| Voir/créer lapins, saillies, soins | ✅ | ✅ | ✅ |
| Voir/créer ventes & rapports PDF | ✅ | ❌ | ✅ |
| Modifier réglages, gérer utilisateurs, sync cloud | ✅ | ❌ | ✅ |
| Supprimer | ✅ | ❌ | ✅ |

---

## 🎯 Roadmap au-delà de V2.2

✅ **Phase 1 (V2.1)** — stabilisation, chiffrement DB, permissions Android, 0 warning analyzer
✅ **Phase 2 (V2.2)** — module Cages complet + photos lapins facultatives
🟦 **Phase 3** — refonte UX/UI (bottom nav 5 onglets, Material 3 polish, dark mode, onboarding, courbes croissance fl_chart)
🟦 **Phase 4** — tâches avancées (priorité/catégorie/récurrence), suivi dépenses + coût production, calculatrices pro, pedigree PDF 4 générations, export CSV
🟦 **Phase 5** — production-ready Play Store (icône custom, splash natif, signing, RGPD, crash reporting, FAQ/glossaire intégrés, .aab, screenshots, fiche store)
