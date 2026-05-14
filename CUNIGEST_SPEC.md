# CuniGest — Spécification Complète (V2.4)

App Flutter Android de gestion d'élevage cunicole. 100% offline (SQLite chiffré), sync cloud optionnelle (Supabase).

## Stack

| Couche | Tech |
|---|---|
| Lang/UI | Dart 3, Flutter Material 3 |
| State | provider 6.x |
| DB locale | sqflite_sqlcipher 3.x (AES-256), clé dans flutter_secure_storage (Keystore) |
| Notifications | flutter_local_notifications + timezone + flutter_timezone |
| Fichiers | path_provider, share_plus, file_picker |
| QR | qr_flutter (gen) + mobile_scanner (scan) |
| PDF | pdf + printing (pw.BarcodeWidget pour QR cages) |
| Photos | image_picker + path_provider |
| Sync | http (Supabase REST), auth JWT email/pwd |
| Auth locale | crypto (PIN SHA-256) |
| Charts | fl_chart |

## Architecture

```
lib/
├── main.dart                    # Splash + MultiProvider + routing
├── database/db_helper.dart      # SQLCipher conn + migrations v1→v9 + facade
├── repositories/
│   ├── lot_repository.dart          # Lots + GMQ + IC
│   ├── sync_repository.dart         # File sync cloud (sync_queue)
│   ├── user_repository.dart         # Multi-user PIN
│   ├── cage_repository.dart         # V2.2 — Bâtiments/Clapiers/Cages + déplacements transactionnels
│   ├── pesee_lapin_repository.dart  # 🆕 V2.4 — Pesées individuelles + GMQ auto
│   └── depense_repository.dart      # 🆕 V2.4 — Dépenses + agrégats financiers
├── state/app_state.dart         # ChangeNotifiers: Session, Lapins, Profil, Reglages, AlertesCount
├── services/
│   ├── encryption_key_service.dart  # Clé AES Keystore
│   ├── notification_service.dart    # TZ auto + alertes push
│   ├── backup_service.dart          # Export/restore DB
│   ├── pdf_service.dart             # Rapports PDF mensuel/annuel + étiquettes + pedigree 4 gén. 🆕 V2.4
│   ├── csv_service.dart             # 🆕 V2.4 — Export CSV lapins/ventes/soins/dépenses (share_plus)
│   └── sync_service.dart            # Push/Pull Supabase REST
├── models/                      # lapin, saillie, soin, vente, stock, lot, user, sync_entry, tache (étendu 🆕), alerte, profil, reglages, batiment, clapier, cage, mouvement_cage, pesee_lapin 🆕, depense 🆕
├── screens/                     # auth/, lapins/, reproduction/, sante/, ventes/, alimentation/, lots/, qr/, rapports/, sync/, routine/, alertes/, reglages/, cages/, depenses/ 🆕, outils/ 🆕
├── utils/
└── widgets/                     # common_widgets.dart, growth_chart.dart
```

## DB Schema (SQLite v9, 21 tables)

**lapins**: id, numero_bague(UNIQUE), nom, sexe, race, date_naissance, poids, couleur, statut[actif/sevrage/quarantaine/vendu/mort], cage(legacy text), **cage_id→cages ON DELETE SET NULL** 🆕, **photo_path** 🆕, notes, pere_id→lapins, mere_id→lapins
**saillies**: id, mere_id→lapins, pere_id→lapins, date_saillie, date_mise_bas_prevue(auto J+31), date_mise_bas_reelle, nb_nes, nb_vivants, nb_morts, nb_sevres, date_sevrage, poids_sevrage_total, statut[attente/mise_bas/sevrage/terminé/échec], palpation_positive, notes
**soins**: id, lapin_id→lapins, type_soin, date_soin, date_rappel, produit, dose, veterinaire, cout, delai_attente_jours, notes
**ventes**: id, lapin_id→lapins, date_vente, type_vente[vivant/abattu/lapereau], acheteur, prix_vente, poids, quantite, notes
**stocks**: id, produit, quantite, unite, seuil_minimum, date_expiration, notes
**consommations**: id, stock_id→stocks, quantite, date_consommation
**lots**: id, code(UNIQUE), nombre_initial, poids_initial, statut[en_cours/terminé], date_creation
**pesees**: id, lot_id→lots, poids_total, nombre, date_pesee
**distributions_aliment**: id, lot_id→lots, stock_id→stocks, quantite_kg, date_distribution
**lot_lapins**: lot_id→lots, lapin_id→lapins
**taches_quotidiennes**: id, titre, recurrence[quotidien/hebdo/mensuel/ponctuel], actif, **date_echeance** 🆕, **statut**[en_attente/en_cours/fait/annule] 🆕, **exceptions** (CSV dates désactivées) 🆕
**completions**: id, tache_id→taches, date_completion
**🆕 V2.4 :**
**pesees_lapin**: id, lapin_id→lapins ON DELETE CASCADE, date_pesee, poids(kg), notes — index (lapin_id, date_pesee)
**depenses**: id, date_depense, categorie[aliment/soins/materiel/eau/electricite/reproducteur/transport/autre], montant, description, notes, date_creation
**alertes**: id, type, message, date_alerte, criticite, lue, saillie_id→saillies
**profil_eleveur**: id, nom_elevage, adresse, telephone, email, notes — + badges, reglages (streak, gamification, heures notif)
**users**: id, nom, pin_hash, sel, role[admin/soigneur], date_creation
**sync_queue**: id, tablename, row_id, operation[INSERT/UPDATE/DELETE], payload(JSON), created_at, synced_at
**sync_config**: id, supabase_url, supabase_anon_key, user_id, enabled, last_sync_at, email, access_token, refresh_token

**🆕 V2.2 — Hiérarchie cages :**
**batiments**: id, nom, adresse, notes, date_creation
**clapiers**: id, nom, batiment_id→batiments ON DELETE CASCADE, notes, date_creation
**cages**: id, numero(UNIQUE), clapier_id→clapiers ON DELETE CASCADE, capacite_max(default 1), statut[vide/occupee/gestante/allaitement/sevrage/quarantaine/desinfection/maintenance], notes, date_creation
**mouvements_cage**: id, lapin_id→lapins ON DELETE CASCADE, cage_origine_id→cages ON DELETE SET NULL, cage_destination_id→cages ON DELETE SET NULL, date, motif, notes

PRAGMA foreign_keys=ON. Transactions atomiques. Index sur statut, sexe, dates, updated_at, lapins.cage_id 🆕.

## Modules Fonctionnels

### Cheptel
- Fiches lapins (bague unique, généalogie père/mère multi-gen, **photo facultative non-bloquante** 🆕)
- Recherche/filtre par bague, nom, statut, sexe
- QR code par lapin `cunigest:lapin:<id>:<bague>` — scan caméra → fiche directe
- Compteurs mâles/femelles/actifs
- **Sélecteur de cage** dans la fiche : vue groupée bâtiment→clapier→cage avec capacité dispo (cages pleines bloquées) 🆕

### Cages 🆕 V2.2
- **Hiérarchie** : Bâtiment (libre) → Clapier (libre, contient X cages) → Cage (numéro libre type "C4B1", capacité_max définie par éleveur 1-N)
- **Statuts** : `vide`, `occupee`, `gestante`, `allaitement`, `sevrage`, `quarantaine`, `desinfection`, `maintenance` (chaque statut = couleur + icône)
- **Auto-toggle** `vide` ↔ `occupee` lors d'un déplacement (autres statuts = manuels par l'éleveur)
- **Capacité enforcement** : `CageRepository.deplacerLapin()` transactionnel — compte occupants non-mort/non-vendu, throw si dépassement
- **Historique mouvements** : table `mouvements_cage` trace chaque entrée/sortie/déplacement avec date, origine, destination, motif, notes
- **QR par cage** `cunigest:cage:<id>:<numero>` — scanner unifié ouvre fiche cage OU fiche lapin selon préfixe
- **Étiquettes PDF A4** : 8 par page, header CuniGest + numéro + QR 90×90 + capacité/statut + bâtiment/clapier
- **Vue principale** : ExpansionTiles bâtiment → clapier → grille 3 colonnes de cages, stats header (total cages, occupées, lapins), action "Imprimer toutes les étiquettes"

### Reproduction (cœur métier)
- Saillie: sélection mère+père, **détection consanguinité auto** (3 générations, niveaux: frère/sœur, demi, ancêtre commun)
- Alertes auto: palpation J+10-14, nid J+27-29, mise bas J+30-33
- Palpation positive/négative → prog nid ou re-saillie
- Mise bas: nés vivants, morts-nés, adoptés
- Sevrage: nombre sevrés, pesée globale → création lot d'engraissement
- **Stats**: fertilité, prolificité, mortalité naissance, mortalité pré-sevrage (seuils couleur pro)

### Lots d'engraissement
- Pesées de contrôle → **GMQ** (g/j/lapereau): ≥35 🟢, ≥25 🟠, <25 🔴
- Distributions aliment → **IC** (kg aliment/kg vif): ≤3.5 🟢, ≤4.0 🟠, >4.0 🔴

### Santé
- Soins individuels/collectifs: vaccins (VHD, Myxo), antibio, antiparasitaires
- **Délai d'attente médicament**: bloque vente abattu, pré-rempli selon type soin
- Rappel vaccin alerte 7j avant

### Alimentation & Stocks
- Entrées/sorties, seuil minimum → alerte auto, date expiration

### Ventes
- Individuelle ou lot, types: vivant/abattu/lapereau
- Statut lapin auto→vendu (transactionnel)
- CA total/mensuel

### Pesées individuelles 🆕 V2.4
- Saisie poids + date + notes depuis la fiche lapin
- Courbe de croissance fl_chart (visible si ≥2 pesées)
- GMQ calculé automatiquement entre première et dernière pesée (g/jour)
- Suppression pesée avec confirmation
- Insert pesée met à jour `lapins.poids` automatiquement

### Dépenses 🆕 V2.4
- CRUD complet (montant, catégorie, date, description, notes)
- 8 catégories : aliment, soins, matériel, eau, électricité, reproducteur, transport, autre
- KPI carte : total ce mois / total cette année
- BarChart 6 derniers mois (fl_chart)
- Répartition par catégorie avec barres LinearProgressIndicator
- Liste scrollable avec swipe-to-edit
- Accessible : onglet Plus → Dépenses (visible admins + peutVoirFinances)

### Calculatrices pro 🆕 V2.4
- **Ration alimentaire** : nb lapins × g/j × jours → kg/j + kg total + nb sacs 25 kg
- **Prix de revient** : aliment + soins + autres / nb produit → coût unitaire + marge + % (indicateur rentabilité coloré)
- **Projection croissance GMQ** : poids actuel + GMQ → poids dans 30/60j + jours restants + date estimée
- Calcul instantané (pas de stockage), 3 onglets TabBar
- Accessible : onglet Plus → Calculatrices

### Pedigree PDF 4 générations 🆕 V2.4
- Arbre récursif `_PedigreeNode` jusqu'à 4 générations (père, mère, GP, arrière-GP)
- Format A4 paysage, 5 colonnes (sujet + 4 gén.)
- Cellules colorées : bleu (mâle), rose (femelle), gris (inconnu)
- Affiche : bague, nom, race
- Bouton `account_tree` dans l'AppBar de la fiche lapin → aperçu + impression/partage

### Export CSV 🆕 V2.4
- 4 exports : Lapins (cheptel), Ventes, Soins, Dépenses
- Encodage RFC 4180, BOM UTF-8 (compatibilité Excel/LibreOffice)
- Partage via Android intent chooser (share_plus)
- Accessible : onglet Plus → Export CSV → bottom sheet de sélection

### Routines & Gamification (désactivable)
- Tâches: quotidien/hebdo/mensuel/ponctuel (hebdo+mensuel visibles toute la période)
- **Date échéance** sur tâches ponctuelles 🆕 V2.4
- **Statut** de tâche : en_attente / en_cours / fait / annulé 🆕 V2.4
- Streak avec tolérance configurable (0-3j), niveaux 1→50, 10 badges
- Notifications matin/midi/soir (heures configurables, TZ auto)

### Rapports PDF
- Mensuel: KPI saillies, naissances, ventes, soins, finances
- Annuel: récap + détail mensuel
- Étiquettes cages : 8 par A4 avec QR scannable 🆕 V2.2
- Actions: aperçu, partage, impression

### Sauvegarde
- Export DB locale, partage via apps, restauration depuis .db (backup auto de sécurité)

## Multi-utilisateur

| Action | Admin | Soigneur | Solo |
|---|---|---|---|
| CRUD lapins, saillies, soins | ✅ | ✅ | ✅ |
| Ventes, rapports PDF, finances | ✅ | ❌ | ✅ |
| Réglages, users, sync, suppression | ✅ | ❌ | ✅ |

Auth PIN 4-6 chiffres (SHA-256+sel). Mode solo si aucun user créé.

## Sync Cloud Supabase

**Serveur** (projet `psqjcgdzauwsdplxgdjn`, eu-west-1): 8 tables miroirs, PK composite `(user_id, id)`, RLS `auth.uid()=user_id`, trigger `updated_at`, soft-delete `deleted_at`, index `(user_id, updated_at desc)`.

**Client**:
- Auth email/pwd (signUp, signIn, signOut, refresh JWT auto sur 401)
- **Push**: upsert REST `on_conflict=user_id,id`, delete→soft-delete via PATCH
- **Pull**: GET delta `updated_at>lastSync`, upsert local ou delete si `deleted_at` set, skip rows pending dans sync_queue
- Config pré-remplie, ne bloque jamais les ops métier

## Sécurité

| Surface | Protection |
|---|---|
| Données au repos | SQLCipher AES-256, clé Keystore |
| Multi-user UI | PIN SHA-256 |
| Réseau | TLS + JWT Supabase |
| RLS serveur | `auth.uid()=user_id` toutes ops |
| Conflits sync | last-write-wins + protection pending |
| Token expiry | Refresh auto 401 |

Migration auto base non-chiffrée→chiffrée via `sqlcipher_export()` (backup `.legacy.bak`).
Si réinstall app → clé Keystore perdue → restaurer via sauvegarde exportée.

## Cas d'Utilisation (résumé)

**Acteurs**: Éleveur/Admin (accès complet), Soigneur (saisie quotidienne, pas finances), Système (alertes auto, sync).

| ID | Cas | Déclencheur | Résultat |
|---|---|---|---|
| UC-101 | Ajouter reproducteur | Btn Ajouter sur Inventaire | Fiche créée + QR généré |
| UC-102 | Réformer/sortir animal | Sélection motif (vente/mort/abattage) | Animal archivé |
| UC-201 | Enregistrer saillie | Scan QR femelle + choix mâle | Tâche palpation J+12 créée |
| UC-202 | Palpation | Liste tâches du jour | Si +: prog nid J+28. Si -: re-saillie |
| UC-203 | Mise bas | Sélection femelle post-naissance | Portée créée, liée à mère |
| UC-204 | Sevrage | Sélection portée (~J+35) | Lot d'engraissement créé |
| UC-301 | Soin médical | Sélection individu/lot + médicament | Icône délai d'attente affiché |
| UC-302 | Vaccination groupée | Sélection vaccin + bâtiment | Soins enregistrés en masse |
| UC-401 | Pesée contrôle | Sélection lot + poids | GMQ calculé auto |
| UC-501 | Gestion aliment | Livraison/consommation | IC calculé par lot |
| UC-601 | Saisie offline | Toute op sans réseau | Stocké SQLite + sync_queue |
| UC-602 | Sync cloud | Btn Synchroniser ou auto | Push pending + pull delta |
| UC-603 | Bilan PDF | Sélection période | PDF: fertilité, production, pertes, finances |

## Installation

```bash
# Prérequis: Flutter SDK, Android Studio + SDK Tools
flutter pub get
flutter run          # dev
flutter build apk --release  # production → build/app/outputs/flutter-apk/app-release.apk
```

minSdkVersion 21. Permissions Android déclarées : CAMERA (QR + photos), INTERNET + ACCESS_NETWORK_STATE (sync cloud), POST_NOTIFICATIONS + SCHEDULE_EXACT_ALARM + RECEIVE_BOOT_COMPLETED + VIBRATE (alertes). Core library desugaring activé.

## UX
Material 3, couleurs nature (vert forêt/terre). Boutons larges, formulaires aérés (usage terrain gants/soleil). Code couleur: 🔴 critique, 🟠 important, 🟢 OK. Confirmation avant actions destructives.

## Changelog technique

**V2.1.1 (Phase 1 — stabilisation, 2026-04-30)**
- Fix: permission CAMERA, INTERNET, ACCESS_NETWORK_STATE manquaient au AndroidManifest (QR scan + sync cassés en release).
- Add: statut lapin "quarantaine" (bio-sécurité — animal isolé/observation).
- Cleanup: 21 issues analyzer → 0 (BuildContext post-async, const constructors, imports, deprecations PDF).
- Build release vérifié : APK 81,7 MB OK.
- Note: warnings Gradle "Java 8 obsolete" venant des plugins natifs — sera traité Phase 5.

**V2.4.0 (Phase 4 — Outils pro & finances, 2026-05-01)**
- Add: `pesees_lapin` + `depenses` tables (DB v9). `taches_quotidiennes` étendu : `date_echeance`, `statut`, `exceptions`.
- Add: `PeseeLapinRepository` (insert met à jour `lapins.poids`), `DepenseRepository` (agrégats mensuels/catégorie).
- Add: Pesées individuelles sur fiche lapin — saisie, courbe fl_chart, GMQ auto, suppression.
- Add: Module Dépenses — CRUD, 8 catégories, KPI mois/année, BarChart 6 mois, répartition par catégorie.
- Add: Module Calculatrices — ration alimentaire, prix de revient, projection croissance GMQ (3 onglets).
- Add: Pedigree PDF 4 générations — arbre récursif `_PedigreeNode`, A4 paysage, colonnes colorées, aperçu/impression.
- Add: Export CSV — lapins, ventes, soins, dépenses. RFC 4180 + BOM UTF-8 + partage share_plus.
- Add: Tâches avancées — statut [en_attente/en_cours/fait/annulé], date échéance sur tâches ponctuelles.
- Add: `CsvService.instance` singleton avec 4 méthodes d'export.
- Extend `PlusScreen` : tuiles Dépenses, Calculatrices, Export CSV (bottom sheet).
- Extend `LapinDetailScreen` : bouton pedigree (AppBar), section pesées, GrowthChart.
- Version : `2.4.0+7`.

**V2.3.0 (Phase 3 — Refonte UX/UI complète, 2026-05-01)**
- Add: `MainScaffold` avec bottom navigation Material 3 — 5 onglets : **Tableau / Cheptel / Repro / Santé / Plus**.
- Add: `DashboardScreen` recentré sur les KPIs + bannières (rappels, stocks, streak), suppression de la grille de modules redondante.
- Add: `PlusScreen` regroupant les modules secondaires (Cages, Lots, Aliment, Ventes, Rapports, Stats, Routine, Scanner QR, Sync, Users, Réglages).
- IndexedStack pour conserver l'état de chaque onglet (pas de reload au switch).
- **Dark mode** : `ThemeMode.system|light|dark` configurable. `AppTheme._build(brightness)` génère les 2 thèmes (cards #1E1E1E, scaffold #121212, navbar #1A1A1A, inputs #2A2A2A en sombre).
- **Onboarding 3 écrans** au premier lancement : bienvenue, choix du thème, conseils de démarrage. Flag `reglages.onboarding_done`.
- **Courbe de croissance** `GrowthChart` widget réutilisable basé sur `fl_chart` — intégré dans la fiche lot (poids moyen par lapin dans le temps, dark-mode aware, tooltip tactile).
- **EmptyState polish** : icône cerclée colorée, message gras + hint optionnel, bouton ajout avec icône, dark-mode aware.
- Migration DB v7→v8 : `reglages.theme_mode TEXT DEFAULT 'system'` + `reglages.onboarding_done INTEGER DEFAULT 0`.
- Cleanup : suppression `backgroundColor: AppTheme.background` forcé sur 26 Scaffolds (laisse le thème choisir).
- Suppression de l'ancien `home_screen.dart`.
- 0 issue analyzer.

**V2.2.0 (Phase 2 — module Cages + photos lapins, 2026-05-01)**
- Add: hiérarchie complète **Bâtiment → Clapier → Cage** (4 nouveaux modèles, CageRepository, 4 nouvelles tables SQLite v7, migration auto).
- Add: 8 statuts cage (vide/occupee/gestante/allaitement/sevrage/quarantaine/desinfection/maintenance) avec couleur+icône.
- Add: déplacement de lapin transactionnel avec contrôle capacité + historique `mouvements_cage`.
- Add: QR cages `cunigest:cage:<id>:<numero>` — scanner unifié lapin/cage.
- Add: génération PDF étiquettes A4 (8/page) avec QR 90×90 scannable.
- Add: vue principale Cages (bâtiment → clapier → grille de cages, stats, action impression globale).
- Add: photos lapins **facultatives non-bloquantes** (image_picker camera/galerie, stockage `<appDocs>/lapins/`).
- Add: sélecteur de cage dans fiche lapin (vue hiérarchique, blocage si pleine).
- Add: backward-compat `cage` legacy text → `cageLegacy` + getter `cage` pour compatibilité écrans existants.
- Migration v6→v7 : ajoute 4 tables + colonnes `lapins.cage_id` (FK) et `lapins.photo_path` + index `idx_lapins_cage`.
- 0 issue analyzer maintenue.
