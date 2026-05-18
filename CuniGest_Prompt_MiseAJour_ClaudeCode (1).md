# CuniGest — Prompt de mise à jour pour Claude Code
## Version 1.2 — Intégration nouvelle modélisation + nouveaux écrans

---

## CONTRAINTES TECHNIQUES DÉTECTÉES — LIRE EN PRIORITÉ

> ⚠️ Ces deux points sont **non négociables**. Ne pas les respecter casserait l'app existante.

### ❌ NE PAS migrer Provider → Riverpod
L'app existante utilise **Provider** sur 36 écrans. Migrer vers Riverpod nécessiterait de réécrire chaque écran — trop risqué et inutile.
- **Conserver Provider** pour toute la gestion d'état existante
- **Écrire les nouveaux modules également en Provider** pour rester cohérent
- Ne pas introduire Riverpod, même partiellement

### ❌ NE PAS migrer sqflite → Drift
L'app utilise **sqflite + SQLCipher** (chiffrement de la base de données locale). Drift ne supporte pas SQLCipher nativement — la migration casserait le chiffrement et exposerait les données des éleveurs.
- **Conserver sqflite + SQLCipher** tel quel
- **Ajouter les nouvelles tables via des migrations sqflite classiques** (ex: `db.execute('CREATE TABLE IF NOT EXISTS ...')` dans `onUpgrade`)
- Incrémenter le numéro de version de la base de données (`version: X+1`)
- Ne pas introduire Drift, même pour les nouvelles tables



Tu travailles sur **CuniGest**, une application Flutter existante de gestion de ferme cunicole développée pour des éleveurs en Afrique (Cameroun). L'app tourne déjà sur Android avec un menu de navigation fonctionnel.

Je vais te fournir :
1. Le **cahier des charges v1.2** (modélisation complète + architecture offline-first)
2. Les **maquettes visuelles** des nouveaux écrans (captures HTML)
3. Les **captures d'écran** de l'app existante

---

## CE QUE TU DOIS ABSOLUMENT CONSERVER

### ✅ Menu de navigation bas — NE PAS TOUCHER
```
Tableau | Cheptel | Repro | Santé | Plus
```
Ces 5 onglets doivent rester identiques, dans le même ordre, avec les mêmes icônes.

### ✅ Structure du menu Plus — CONSERVER + ENRICHIR
Le menu Plus actuel contient déjà ces modules en grille 2 colonnes :
- Cages / Lots
- Alimentation / Ventes
- Rapports PDF / Dépenses
- Calculatrices / Stats reproduction
- Ma Routine / Scanner QR
- Sauvegarde cloud / Utilisateurs
- Réglages / Export CSV

**Ces items doivent rester accessibles exactement où ils sont.**
Les nouvelles fonctionnalités seront ajoutées EN BAS de cette grille, après les items existants.

### ✅ Header existant — CONSERVER
```
[Logo feuille] CuniGest | date | [QR] [🔔] [⚙️]
```

### ✅ Thème sombre (dark mode) — CONSERVER
L'app utilise un fond noir/très sombre. Respecter ce thème pour tous les nouveaux écrans.

### ✅ Palette de couleurs existante — RESPECTER
- Vert principal : #1D9E75 (header, onglet actif)
- Cards sombres avec icônes colorées
- Texte blanc/gris clair sur fond sombre

---

## BUG CRITIQUE À CORRIGER EN PRIORITÉ

Avant toute nouvelle fonctionnalité, corriger le bug suivant visible sur toutes les KPI cards du Tableau de bord :

```
⚠️ BOTTOM OVERFLOWED BY 25 PIXELS (cards Tableau de bord)
⚠️ BOTTOM OVERFLOWED BY 17 PIXELS (Stats reproduction)
⚠️ BOTTOM OVERFLOWED BY 29 PIXELS (Sauvegarde cloud)
```

**Cause probable** : hauteur fixe des cards trop petite pour le contenu.
**Solution** : remplacer la hauteur fixe par `fit: FlexFit.loose` ou `mainAxisSize: MainAxisSize.min` sur les Column internes des cards, ou augmenter la hauteur minimale des cards.

---

## NOUVELLES FONCTIONNALITÉS À AJOUTER

### 1. Nouveau modèle de données — Migration sqflite

> ⚠️ Utiliser **uniquement sqflite** (pas Drift). Incrémenter la version de la base et ajouter la logique dans `onUpgrade` du DatabaseHelper existant.

```dart
// Incrémenter : version: ancienneVersion + 1
// Ajouter dans onUpgrade :

if (oldVersion < newVersion) {
  // --- Champs de sync sur tables existantes ---
  // (utiliser try/catch car ALTER TABLE échoue si colonne déjà présente)
  for (final table in ['lapins', 'cages', 'lots', 'saillies', 'ventes']) {
    try { await db.execute('ALTER TABLE $table ADD COLUMN updated_at TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE $table ADD COLUMN deleted_at TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE $table ADD COLUMN is_synced INTEGER DEFAULT 0'); } catch (_) {}
  }

  // --- Nouvelles tables ---
  await db.execute('''CREATE TABLE IF NOT EXISTS pesees (
    id TEXT PRIMARY KEY, lapin_id TEXT NOT NULL, date TEXT NOT NULL,
    poids_kg REAL NOT NULL, updated_at TEXT, deleted_at TEXT, is_synced INTEGER DEFAULT 0)''');

  await db.execute('''CREATE TABLE IF NOT EXISTS mortalites (
    id TEXT PRIMARY KEY, lapin_id TEXT, lot_id TEXT, date TEXT NOT NULL,
    cause TEXT, updated_at TEXT, deleted_at TEXT, is_synced INTEGER DEFAULT 0)''');

  await db.execute('''CREATE TABLE IF NOT EXISTS traitements_sanitaires (
    id TEXT PRIMARY KEY, lapin_id TEXT, lot_id TEXT, date TEXT NOT NULL,
    type TEXT NOT NULL, produit TEXT, dose TEXT,
    updated_at TEXT, deleted_at TEXT, is_synced INTEGER DEFAULT 0)''');

  await db.execute('''CREATE TABLE IF NOT EXISTS clients (
    id TEXT PRIMARY KEY, nom TEXT NOT NULL, type TEXT,
    telephone TEXT, localisation TEXT,
    updated_at TEXT, deleted_at TEXT, is_synced INTEGER DEFAULT 0)''');

  await db.execute('''CREATE TABLE IF NOT EXISTS transactions_compta (
    id TEXT PRIMARY KEY, date TEXT NOT NULL, type TEXT NOT NULL,
    categorie TEXT, montant REAL NOT NULL, description TEXT, reference_id TEXT,
    updated_at TEXT, deleted_at TEXT, is_synced INTEGER DEFAULT 0)''');

  await db.execute('''CREATE TABLE IF NOT EXISTS sync_queue (
    id TEXT PRIMARY KEY, table_name TEXT NOT NULL, record_id TEXT NOT NULL,
    operation TEXT NOT NULL, payload TEXT NOT NULL,
    created_at TEXT NOT NULL, synced_at TEXT, retry_count INTEGER DEFAULT 0)''');

  await db.execute('''CREATE TABLE IF NOT EXISTS notifications_log (
    id TEXT PRIMARY KEY, type TEXT NOT NULL, declencheur TEXT,
    date_rappel TEXT, recurrence TEXT, statut TEXT DEFAULT 'en_attente',
    entite_id TEXT, created_at TEXT NOT NULL)''');
}
```

---

### 2. Système Offline-First — SyncManager

Créer `lib/data/sync/sync_manager.dart` :

```dart
// Logique à implémenter :
// 1. ConnectivityService : écouter connectivity_plus pour détecter retour réseau
// 2. À chaque modification locale → ajouter entrée dans sync_queue
// 3. Au retour du réseau → vider la sync_queue vers Supabase
// 4. Résolution des conflits : comparer updated_at local vs cloud → garder le plus récent
// 5. Soft delete : ne jamais DELETE en base, toujours SET deleted_at = now()
// 6. Exposer un Stream<SyncStatus> (synced | pending | error) pour l'UI
```

Afficher l'indicateur de sync dans le header existant (à côté de la cloche) :
- 🟢 Point vert = tout synchronisé
- 🟡 Point jaune animé = synchronisation en cours / en attente
- 🔴 Point rouge = erreur (tap pour voir détails)

---

### 3. Nouveaux écrans à ajouter dans le menu Plus

Ajouter les items suivants EN BAS de la grille Plus existante, en respectant le style dark mode et la grille 2 colonnes :

#### 3.1 — Fiche Lapin détaillée (amélioration de Cheptel)
> Accessible depuis l'onglet Cheptel → tap sur un lapin

Ajouter dans la fiche lapin existante :
- **Courbe de poids** : graphique fl_chart avec les pesées dans le temps
- **Timeline historique** : saillies, mises bas, vaccins, pesées dans l'ordre chronologique inverse
- **Boutons d'action rapide** : + Pesée / + Traitement / + Événement
- **Prochaine saillie calculée** : date_mise_bas + 12 jours (affichée en vert)

#### 3.2 — Saisie Saillie améliorée (amélioration de Repro)
> Accessible depuis l'onglet Repro

Enrichir le formulaire de saillie existant avec le **cycle complet terrain** :

**Étape 1 — Saillie (J0)**
- Champ heure de la saillie
- Champ nb chevauchements réussis observés
- ⚠️ Afficher le rappel : "Toujours déplacer la femelle vers le mâle"
- Calculs automatiques affichés : palpation prévue J+10, nid J+28, mise bas J+31

**Étape 2 — Palpation (J+10 à J+14) — rappel automatique**
- Résultat : Positive / Négative
- Si **Négative** → alerte rouge immédiate : "Remettre la femelle au mâle immédiatement"
- Si Positive → confirmation gestation, rappel pose nid J+28

**Étape 3 — Pose boîte à nid (J+28) — rappel automatique**
- État : Propre / Garni / Non posé
- Notes libres (copeaux, paille, arrachage de poils observé)

**Étape 4 — Mise bas (J+31/32) — rappel automatique**
- Date réelle de mise bas
- Nb nés vivants / nés morts
- Création automatique du lot lapereaux

**Étape 5 — Sevrage (J+35 à J+42) — rappel automatique**
- Date de séparation mère/lapereaux
- Poids total de la portée (pesée)
- Nb lapereaux sevrés
- Case à cocher : traitement anti-coccidien administré
- Calcul automatique : poids moyen lapereau

**Notifications programmées automatiquement à la saillie :**
```dart
scheduleNotification(saillie.date + 10, "Palpation abdominale — vérifier gestation");
scheduleNotification(saillie.date + 14, "Palpation — dernier délai");
scheduleNotification(saillie.date + 28, "Poser la boîte à nid — nettoyer et garnir");
scheduleNotification(saillie.date + 29, "Mise bas demain — surveillance discrète");
scheduleNotification(miseBasDate + 1,   "Inspecter le nid — compter les lapereaux");
scheduleNotification(miseBasDate + 4,   "Contrôle mamelles — détecter mammite");
scheduleNotification(miseBasDate + 7,   "Pesée lapereaux — objectif >80g");
scheduleNotification(miseBasDate + 18,  "Sortie du nid — lapereaux grignotent");
scheduleNotification(miseBasDate + 35,  "Sevrage — séparer mère et lapereaux");
scheduleNotification(sevrageDate,       "Traitement anti-coccidien dans l'eau — 7 jours");
```

#### 3.3 — Stock & Alertes (NOUVEAU dans menu Plus)
> Nouveau module : icône entrepôt, couleur corail #D85A30

```
Titre : "Stock & Alertes"
Sous-titre : "Seuils & médicaments"
```

Écran avec :
- Liste des stocks (aliments + médicaments) avec barre de progression colorée
  - Rouge : quantite < seuil_alerte
  - Amber : quantite < seuil_alerte × 1.5
  - Vert : quantite >= seuil_alerte × 1.5
- Bouton "+" pour ajouter/modifier un article
- Alerte automatique (flutter_local_notifications) si stock passe sous le seuil

#### 3.4 — Notifications & Bonnes pratiques (NOUVEAU dans menu Plus)
> Nouveau module : icône cloche avec check, couleur violet #7F77DD

```
Titre : "Alertes & Routine"
Sous-titre : "Rappels & bonnes pratiques"
```

Écran avec 3 sections (voir maquette) :
- **URGENT** : alertes stock bas, mortalité anormale
- **ROUTINE DU MATIN** : abreuvoirs, observation, aération, retrait morts (checkable)
- **ÉLEVAGE — STADES** : contrôle mamelles, pesée lapereaux, vaccination, saillie planifiée

Programmer ces notifications locales via flutter_local_notifications :
```dart
// Routine du matin — chaque jour
scheduleDaily(time: TimeOfDay(hour: 6, minute: 30), title: "Vérifier les abreuvoirs");
scheduleDaily(time: TimeOfDay(hour: 6, minute: 45), title: "Observer le comportement");
scheduleDaily(time: TimeOfDay(hour: 7, minute: 0),  title: "Vérifier les lapins morts");
scheduleDaily(time: TimeOfDay(hour: 7, minute: 15), title: "Aérer le bâtiment");

// Calendrier fixe
scheduleEveryNDays(3, title: "Nettoyage et désinfection des cages");
scheduleWeekly(title: "Contrôle stock aliments");
scheduleEveryNDays(14, title: "Inspection matériel et cages");
```

#### 3.5 — Rapport financier enrichi (amélioration de Rapports PDF)
> Enrichir le module Rapports PDF existant

Ajouter dans les rapports existants :
- **Top clients** du mois (classement par montant)
- **Évolution du cheptel** sur 6 mois (graphique fl_chart area chart)
- **Marge bénéficiaire** = recettes - dépenses
- Export **CSV** en plus du PDF existant

---

### 4. Authentification Google + Supabase

Si l'app utilise déjà une authentification, migrer vers Supabase Auth + Google Sign-In.
Si pas encore d'auth, ajouter un écran de connexion :

```dart
// Écran login_screen.dart
// - Logo CuniGest centré
// - Bouton "Continuer avec Google" (style officiel)
// - Sous-texte : "Vos données sauvegardées automatiquement"
// - Sélecteur langue FR / EN avant connexion
// - Après connexion → redirection automatique vers Tableau de bord
// GoRouter auth guard : redirect to /login if user == null
```

Chaque enregistrement en base doit avoir un champ `user_id` lié au compte Google.

---

## ORDRE D'EXÉCUTION RECOMMANDÉ

```
Étape 1 : Corriger les bugs BOTTOM OVERFLOWED (quick win visible immédiatement)
Étape 2 : Mettre à jour le schéma drift (nouvelles tables + champs sync)
Étape 3 : Implémenter SyncManager + ConnectivityService + indicateur UI
Étape 4 : Ajouter Stock & Alertes dans le menu Plus
Étape 5 : Ajouter Alertes & Routine dans le menu Plus
Étape 6 : Enrichir la fiche lapin (courbe de poids + timeline)
Étape 7 : Enrichir la saisie saillie (calculs automatiques + notifications)
Étape 8 : Enrichir les rapports (top clients + graphiques + CSV)
Étape 9 : Ajouter authentification Google + Supabase
```

---

## RÈGLES À RESPECTER POUR TOUT NOUVEAU CODE

```
✅ Thème sombre obligatoire — fond #121212 ou #1A1A1A, texte blanc
✅ Grille 2 colonnes pour les items du menu Plus
✅ Style de card existant — bord arrondi, fond sombre, icône colorée en haut
✅ Même police et taille de texte que l'app existante
✅ Tout fonctionne SANS connexion internet (offline-first)
✅ Chaque modification → ajout dans sync_queue avant tout
✅ Ne jamais DELETE physiquement → toujours soft delete (deleted_at)
✅ Provider pour la gestion d'état (pas Riverpod)
✅ sqflite + SQLCipher pour la base de données (pas Drift)
✅ GoRouter pour la navigation
✅ Bilangue FR/EN — utiliser les fichiers arb existants, ajouter les nouvelles clés
```

---

## FICHIERS DE RÉFÉRENCE À LIRE AVANT DE COMMENCER

Avant d'écrire la moindre ligne de code, lis ces 3 documents :

1. `CuniGest_Cahier_des_Charges.md` — modèle de données complet (section 2), règles métier (section 6), architecture offline-first détaillée (section 5.2)
2. `CuniGest_Figma_Design_Prompts.md` — description visuelle détaillée de chaque écran
3. Les captures d'écran de l'app existante fournies ci-dessus

---

## RÉSUMÉ EN UNE PHRASE

> Corrige les bugs overflow, ajoute Stock & Alertes + Alertes & Routine dans le menu Plus, enrichis la fiche lapin et la saisie saillie, implémente le SyncManager offline-first avec Supabase — sans jamais toucher au menu de navigation ni aux modules existants.

---

*CuniGest Prompt Claude Code v1.2 — Mai 2025*
