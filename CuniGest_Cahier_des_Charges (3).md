# CuniGest
## Application mobile de gestion de ferme cunicole
### Cahier des charges technique — Prêt pour Claude Code
**Version 1.0 — Mai 2025**

> *Conçu par un cuniculteur, pour les cuniculteurs d'Afrique*

---

## Table des matières

1. [Contexte et objectif](#1-contexte-et-objectif)
2. [Modèle de données — Diagramme de classes](#2-modèle-de-données)
3. [Système de notifications et bonnes pratiques](#3-notifications)
4. [Écrans de l'application](#4-écrans)
5. [Architecture technique](#5-architecture-technique)
6. [Règles métier](#6-règles-métier)
7. [Design system et palette de couleurs](#7-design-system)
8. [Priorités de développement](#8-priorités)
9. [Prompt de démarrage pour Claude Code](#9-prompt-claude-code)

---

## 1. Contexte et objectif

CuniGest est une application mobile **bilangue (Français / English)** destinée aux cuniculteurs en Afrique, notamment au Cameroun. Elle est conçue pour un cuniculteur-propriétaire ayant des notions informatiques de base, qui souhaite gérer l'intégralité de sa ferme depuis son smartphone.

### 1.1 Problème résolu

Aujourd'hui, la gestion d'une ferme cunicole se fait sur papier ou de mémoire, ce qui entraîne :
- Des pertes d'information (dates de saillie, vaccinations, poids)
- Une difficulté à suivre la rentabilité réelle
- L'absence de rappels pour les bonnes pratiques d'hygiène et de santé

### 1.2 Utilisateurs cibles

| Rôle | Accès |
|---|---|
| Propriétaire / cuniculteur | Accès complet |
| Ouvriers / employés de la ferme | Saisie et consultation |
| Fermes partenaires | Accès partagé (futur) |

### 1.3 Plateforme cible

- Application mobile **Flutter** (iOS + Android — un seul codebase en Dart)
- Backend **Supabase** (PostgreSQL + Auth + Storage + Realtime)
- Authentification via **Google Sign-In** (OAuth 2.0)
- Fonctionne **hors ligne** avec synchronisation automatique sur le cloud Supabase
- Interface en **Français et Anglais** (switch dans les paramètres)

---

## 2. Modèle de données

Le modèle est organisé en 6 modules fonctionnels.

### 2.1 Module Utilisateurs

```
Utilisateur
├── id : UUID
├── nom : String
├── role : Enum (proprietaire | ouvrier)
├── telephone : String
└── ferme_id : UUID → Ferme

Ferme
├── id : UUID
├── nom : String
├── localisation : String
└── date_creation : Date
```

### 2.2 Module Production

```
Lapin
├── id : UUID
├── code : String
├── sexe : Enum (M | F)
├── race : String
├── date_naissance : Date
├── statut : Enum (actif | vendu | mort)
├── cage_id : UUID → Cage
└── lot_id : UUID → Lot

Lot
├── id : UUID
├── nom : String
├── stade : Enum (maternite | engraissement | vente)
├── date_creation : Date
└── nombre : Integer

Cage
├── id : UUID
├── code : String
├── type : Enum (maternite | engraissement)
├── capacite : Integer
└── etat : Enum (bon | use | reparation)

Saillie
├── id : UUID
├── date_saillie : Date
├── date_mise_bas_prevue : Date  ← calculée automatiquement (J+31)
├── femelle_id : UUID → Lapin
├── male_id : UUID → Lapin
└── statut : Enum (prevue | reussie | echouee)

Mise_bas
├── id : UUID
├── date : Date
├── nb_nes_vivants : Integer
├── nb_nes_morts : Integer
├── saillie_id : UUID → Saillie
└── lot_cree_id : UUID → Lot

Pesee
├── id : UUID
├── date : Date
├── poids_kg : Float
└── lapin_id : UUID → Lapin

Mortalite
├── id : UUID
├── date : Date
├── cause : String
├── lapin_id : UUID → Lapin (optionnel)
└── lot_id : UUID → Lot (optionnel)
```

### 2.3 Module Santé

```
Traitement_sanitaire
├── id : UUID
├── date : Date
├── type : Enum (vaccin | medicament)
├── produit : String
├── dose : String
├── lapin_id : UUID → Lapin (optionnel)
└── lot_id : UUID → Lot (optionnel)

Alimentation
├── id : UUID
├── date : Date
├── quantite_kg : Float
├── aliment_id : UUID → Stock
└── lot_id : UUID → Lot
```

### 2.4 Module Vente et Comptabilité

```
Vente
├── id : UUID
├── date : Date
├── type : Enum (poids_vif | carcasse)
├── quantite : Float
├── prix_unitaire : Float
├── montant_total : Float  ← calculé automatiquement
├── client_id : UUID → Client
└── lot_id : UUID → Lot

Client
├── id : UUID
├── nom : String
├── type : Enum (particulier | boucher | restaurant | ferme)
├── telephone : String
└── localisation : String

Transaction
├── id : UUID
├── date : Date
├── type : Enum (achat | vente | depense)
├── categorie : String
├── montant : Float
├── description : String
└── reference_id : UUID  ← lien vers Vente ou saisie manuelle
```

### 2.5 Module Matériel et Stock

```
Stock
├── id : UUID
├── nom : String
├── type : Enum (aliment | medicament)
├── quantite : Float
├── unite : String
└── seuil_alerte : Float  ← déclenche une notification si quantite < seuil

Equipement
├── id : UUID
├── nom : String
├── type : String
├── etat : Enum (bon | use | reparation)
├── date_achat : Date
└── valeur : Float
```

### 2.6 Module Notifications et Rapports

```
Notification
├── id : UUID
├── type : Enum (saillie | vaccin | pesee | stock_bas | mortalite |
│              abreuvoir | nettoyage | observation | aeration |
│              mamelles | sevrage | equipement)
├── declencheur : Enum (heure_fixe | calendrier_periodique | evenement_stade)
├── date_rappel : DateTime
├── recurrence : String  ← ex: "quotidien", "tous_les_3_jours", "J+7"
├── statut : Enum (en_attente | envoyee | lue)
└── entite_id : UUID  ← lapin, lot, ou stock concerné

Rapport
├── id : UUID
├── type : Enum (production | sante | financier)
├── periode : DateRange
├── donnees : JSON  ← données brutes pour modélisation future
├── genere_le : DateTime
└── ferme_id : UUID → Ferme
```

---

## 3. Notifications

Trois niveaux de déclenchement sont implémentés.

### 3.1 Routine du matin (heure fixe — chaque jour)

| Notification | Heure | Message affiché |
|---|---|---|
| Vérifier les abreuvoirs | 06h30 | "Avez-vous vérifié l'eau de chaque cage ? Un lapin sans eau 4h refuse de manger." |
| Tour d'observation du comportement | 06h45 | "Observez : poil ébouriffé, diarrhée, isolement = signe précoce de maladie." |
| Retrait des lapins morts | 07h00 | "Vérifiez chaque cage. Un cadavre propage les maladies. Enregistrez la cause." |
| Aération du bâtiment | 07h15 | "Ouvrez les fenêtres. L'ammoniaque des urines cause des maladies respiratoires." |

### 3.2 Calendrier fixe (récurrence périodique)

| Notification | Fréquence | Action attendue |
|---|---|---|
| Nettoyage et désinfection des cages | Tous les 3 jours | Gratter, rincer, désinfecter. Obligatoire après tout décès. |
| Contrôle stock aliments | Chaque semaine | Alerte auto si `quantite < seuil_alerte` |
| Contrôle stock médicaments | Chaque semaine | Vaccins et antiparasitaires disponibles en permanence |
| Inspection matériel et cages | Toutes les 2 semaines | Grillages, abreuvoirs, mangeoires — prévenir les blessures |

### 3.3 Événements selon le stade (calcul automatique)

Ces notifications sont programmées **automatiquement** lors de l'enregistrement d'une Saillie ou Mise bas.

| Événement déclencheur | Notification générée | Délai |
|---|---|---|
| Mise bas enregistrée | Contrôle mamelles (mammite) | J+4, J+10, J+20 |
| Mise bas enregistrée | Comptage et pesée des lapereaux | J+7 |
| Mise bas enregistrée | Rappel sevrage | J+21 |
| Mise bas enregistrée | Sevrage complet | J+28 à J+35 selon race |
| Saillie enregistrée | Rappel mise bas prévue | J+28 (alerte anticipée) |
| Dernier vaccin enregistré | Rappel prochain vaccin VHD | 6 mois après |
| Pesée enregistrée | Rappel pesée suivante (engraissement) | 7 jours après |
| Mortalité anormale | Notification urgente | Seuil : >2 décès / semaine |

---

## 4. Écrans

L'application comporte **5 écrans principaux** accessibles via une barre de navigation en bas.

### 4.0 Écran de connexion (Login)

Couleur principale : `#1D9E75` vert teal.

- Logo CuniGest centré avec illustration lapin
- Titre bilangue : "Gérez votre ferme · Manage your farm"
- Bouton **"Continuer avec Google"** (style officiel Google Sign-In)
- Sous-texte : "Vos données sont sauvegardées dans le cloud automatiquement"
- Langue sélectionnable : Français / English avant connexion
- Après connexion : redirection automatique vers le tableau de bord

### 4.1 Tableau de bord (Dashboard)

Couleur principale : `#1D9E75` vert teal.

- **En-tête** : salutation bilangue, nom de la ferme, date du jour, icône de notification avec badge
- **KPI cards (2×2)** : Total lapins, Ventes/mois (FCFA), Mortalité/mois, Stock aliment
- **Alertes du jour** : liste des notifications prioritaires avec icône colorée par type
- **Graphique de croissance** : barres horizontales — poids moyen par semaine du lot en engraissement
- **Lots actifs** : liste avec badge de stade (Engraissement / Maternité / À vendre)
- **Donut chart** : répartition des lapins par stade

### 4.2 Fiche lapin

Couleur principale : `#1D9E75` vert teal.

- **En-tête** : nom, code, race, sexe, statut (pill colorée)
- **KPI** : poids actuel (kg), nombre de portées, âge en mois
- **Informations** : date de naissance, cage, lot, mâle reproducteur, prochaine saillie, dernier vaccin
- **Courbe de poids** : sparkline SVG avec points de pesée chronologiques
- **Chronologie (timeline)** : historique inversé — mises bas, saillies, vaccins, pesées, contrôles
- **Boutons d'action rapide** : `+ Saillie` / `+ Pesée` / `+ Traitement` / `+ Événement`

### 4.3 Saisie d'une saillie

Couleur principale : `#7F77DD` violet.

- Indicateur de progression (3 étapes)
- Sélection femelle : pré-remplie si navigation depuis fiche lapin
- Sélection mâle : liste des mâles disponibles, tri par utilisation récente
- Date de saillie : date-picker, défaut = aujourd'hui
- **Dates calculées automatiquement** : mise bas prévue (J+31), sevrage prévu (J+28 après mise bas)
- Résultat saillie : `Réussie` / `Douteuse` / `Échouée` (sélecteur 3 options)
- **Bandeau informatif** : récapitule les notifications qui seront programmées automatiquement
- Note libre (optionnel)
- Boutons : `Annuler` / `Enregistrer ✓`

### 4.4 Écran de vente

Couleur principale : `#BA7517` ambre.

- Sélection du lot à vendre
- Type de vente : `Poids vif` ou `Carcasse`
- Saisie du poids total et du prix unitaire
- Calcul automatique du montant total
- Sélection ou création du client (type : particulier, boucher, restaurant, ferme)
- Génération automatique d'une Transaction comptable
- Option : partager un bon de vente simplifié (PDF via WhatsApp / SMS)

### 4.5 Écran Rapports

- Filtres : période (semaine / mois / trimestre), type de rapport
- **Rapport de production** : natalité, mortalité, taux de sevrage, courbes de croissance
- **Rapport financier** : recettes, dépenses, bénéfice net, top clients
- **Rapport santé** : vaccinations réalisées, traitements, incidents
- Export CSV ou PDF
- Collecte de données JSON brutes pour modélisation future (IA / prédictions)

---

## 5. Architecture technique

### 5.1 Stack technologique

| Couche | Technologie recommandée | Justification |
|---|---|---|
| Frontend mobile | **Flutter** (Dart) | iOS + Android en un seul codebase, performances natives |
| Navigation | **GoRouter** | Navigation déclarative + redirection si non connecté |
| State management | **Riverpod** | Gestion d'état réactive, adapté à Flutter |
| Base de données locale | **drift** (sqflite) | SQLite Flutter, fonctionnement hors ligne |
| Backend & Cloud | **Supabase** | PostgreSQL + Auth + Storage + Realtime — gratuit jusqu'à 500 MB |
| Authentification | **Supabase Auth** + **google_sign_in** | Connexion Google OAuth 2.0 en 1 clic |
| Synchronisation cloud | **supabase_flutter** | Sync auto locale ↔ cloud quand connexion disponible |
| Notifications locales | **flutter_local_notifications** | Rappels hors ligne (routine matin, stades) |
| Graphiques | **fl_chart** | Courbes de croissance, donuts, barres — natif Flutter |
| Internationalisation | **flutter_localizations** + **intl** | Français / Anglais intégré Flutter |
| Génération PDF | **pdf** + **printing** | Bons de vente partageables WhatsApp/SMS |

### 5.2 Stratégie Offline-First

> ⚠️ **Priorité absolue** : L'application doit fonctionner à 100% sans connexion internet. La synchronisation cloud est un bonus, pas une dépendance.

#### Principe général
CuniGest suit une architecture **offline-first** : la source de vérité principale est toujours la base de données locale (SQLite via drift). Supabase est utilisé uniquement pour la sauvegarde et la synchronisation inter-appareils.

```
[Utilisateur] → [SQLite local (drift)] ←→ [SyncManager] ←→ [Supabase cloud]
                       ↑                        ↑
              Toujours disponible         Quand réseau dispo
```

#### Ce qui fonctionne SANS connexion
- ✅ Saisie de toutes les données (lapins, saillies, pesées, ventes, traitements...)
- ✅ Consultation de toutes les données existantes
- ✅ Notifications et rappels locaux (flutter_local_notifications)
- ✅ Calculs automatiques (dates, montants, GMQ...)
- ✅ Génération de rapports PDF
- ✅ Tableau de bord et statistiques

#### Ce qui nécessite une connexion
- 🔄 Synchronisation vers Supabase (sauvegarde cloud)
- 🔐 Première connexion Google (une seule fois)
- 👥 Invitation d'un ouvrier / partage multi-appareils

#### File d'attente de synchronisation (SyncQueue)
Chaque modification locale est ajoutée à une **file d'attente** avec son statut :

```dart
// Table sync_queue dans SQLite local
SyncQueue {
  id         : UUID
  table_name : String        // ex: "lapins", "saillies", "ventes"
  record_id  : UUID          // ID de l'enregistrement modifié
  operation  : Enum          // INSERT | UPDATE | DELETE
  payload    : JSON          // données à synchroniser
  created_at : DateTime
  synced_at  : DateTime?     // null = en attente
  retry_count: Integer       // nb de tentatives échouées
}
```

#### Déclenchement de la synchronisation
La synchronisation se déclenche automatiquement dans ces 4 cas :
1. **Retour de connectivité** : détecté via `connectivity_plus`
2. **Ouverture de l'app** : vérification au lancement
3. **Toutes les 15 minutes** : si connexion active (background sync)
4. **Action manuelle** : bouton "Synchroniser" dans Paramètres

#### Gestion des conflits
- Chaque enregistrement a un champ `updated_at : DateTime`
- Règle : **la modification la plus récente gagne** (last-write-wins)
- En cas de conflit détecté : notification discrète à l'utilisateur avec choix de garder local ou cloud

#### Indicateur visuel de sync dans l'UI
- 🟢 Point vert animé dans l'en-tête = synchronisé
- 🟡 Point jaune = modifications en attente de sync
- 🔴 Point rouge = erreur de synchronisation (avec message explicatif)

#### Packages Flutter nécessaires
| Package | Rôle |
|---|---|
| `connectivity_plus` | Détecter retour/perte de connexion en temps réel |
| `drift` | SQLite local — source de vérité principale |
| `supabase_flutter` | Client Supabase pour la sync cloud |
| `workmanager` | Synchronisation en arrière-plan (background sync) |

#### Champs obligatoires sur chaque table (local + Supabase)
```sql
id          UUID PRIMARY KEY DEFAULT gen_random_uuid()
user_id     UUID NOT NULL REFERENCES auth.users(id)
created_at  TIMESTAMP DEFAULT now()
updated_at  TIMESTAMP DEFAULT now()
deleted_at  TIMESTAMP          -- soft delete pour éviter les conflits
is_synced   BOOLEAN DEFAULT false  -- local uniquement
```

> **Soft delete** : les enregistrements supprimés ne sont pas effacés immédiatement — ils sont marqués `deleted_at = now()` et exclus des requêtes. Cela évite les conflits quand un ouvrier supprime un lapin hors ligne pendant que le propriétaire le modifie.

### 5.3 Structure des dossiers

```
cunigest/
├── lib/
│   ├── main.dart                   # Point d'entrée + initialisation
│   ├── app.dart                    # MaterialApp + GoRouter + thème
│   ├── core/
│   │   ├── theme/                  # Couleurs, typographie, composants
│   │   │   └── app_theme.dart
│   │   ├── utils/
│   │   │   └── calculations.dart   # Calculs dates (saillie→mise bas→sevrage)
│   │   └── l10n/                   # Traductions FR / EN
│   │       ├── app_fr.arb
│   │       └── app_en.arb
│   ├── data/
│   │   ├── database/
│   │   │   ├── app_database.dart   # Drift DB schema
│   │   │   └── migrations/
│   │   ├── models/                 # Classes Dart (Lapin, Lot, Saillie…)
│   │   ├── repositories/          # Accès aux données (local + API)
│   │   └── sync/
│   │       ├── sync_manager.dart   # Orchestrateur de synchronisation
│   │       ├── sync_queue.dart     # File d'attente des modifications offline
│   │       └── connectivity_service.dart  # Détection réseau (connectivity_plus)
│   ├── features/
│   │   ├── auth/
│   │   │   ├── login_screen.dart       # Écran de connexion Google
│   │   │   ├── auth_provider.dart      # État connexion Supabase
│   │   │   └── auth_guard.dart         # Redirection si non connecté
│   │   ├── dashboard/
│   │   │   ├── dashboard_screen.dart
│   │   │   └── dashboard_provider.dart
│   │   ├── lapins/
│   │   │   ├── lapin_list_screen.dart
│   │   │   ├── lapin_detail_screen.dart
│   │   │   └── lapin_provider.dart
│   │   ├── production/
│   │   │   ├── saillie_form_screen.dart
│   │   │   ├── mise_bas_form_screen.dart
│   │   │   └── pesee_form_screen.dart
│   │   ├── ventes/
│   │   │   ├── vente_screen.dart
│   │   │   └── vente_provider.dart
│   │   ├── rapports/
│   │   │   └── rapports_screen.dart
│   │   └── notifications/
│   │       └── notification_scheduler.dart
│   └── shared/
│       ├── widgets/
│       │   ├── kpi_card.dart
│       │   ├── timeline_widget.dart
│       │   ├── notif_item.dart
│       │   ├── lot_badge.dart
│       │   └── charts/
│       └── providers/
├── pubspec.yaml                    # Dépendances Flutter
├── supabase/
│   ├── migrations/                 # Scripts SQL Supabase (tables + RLS)
│   │   └── 001_initial_schema.sql
│   └── functions/                  # Edge functions Supabase (optionnel)
└── test/
```

---

## 6. Règles métier

### 6.1 Calculs automatiques

| Événement | Calcul | Formule |
|---|---|---|
| Saillie enregistrée | Date mise bas prévue | `date_saillie + 31 jours` |
| Saillie enregistrée | Date sevrage prévu | `date_mise_bas_prevue + 28 jours` |
| Saillie enregistrée | Prochaine saillie optimale | `date_mise_bas + 12 jours` |
| Vente enregistrée | Montant total | `quantite_kg × prix_unitaire` |
| Vente enregistrée | Transaction comptable | Créée automatiquement (type = vente) |
| Pesée enregistrée | GMQ (Gain Moyen Quotidien) | `(poids_actuel - poids_precedent) / nb_jours` |
| Lot engraissement | Poids moyen du lot | Moyenne des dernières pesées de chaque lapin |

### 6.2 Alertes automatiques

| Condition | Alerte générée | Priorité |
|---|---|---|
| `Stock.quantite < Stock.seuil_alerte` | Alerte stock bas | 🔴 Haute |
| Mortalité > 2 en 7 jours | Alerte mortalité anormale | 🔴 Haute |
| Lapin.poids < 80g à J+7 (lapereau) | Surveillance lapereau fragile | 🟡 Moyenne |
| Saillie sans résultat après 5 jours | Confirmer résultat saillie | 🟢 Normale |
| Vaccin > 6 mois sans rappel | Rappel vaccination | 🔴 Haute |

### 6.3 Gestion des rôles

| Rôle | Permissions |
|---|---|
| **Propriétaire** | Accès complet : création, modification, suppression, rapports, comptabilité |
| **Ouvrier** | Saisie uniquement : pesées, alimentations, observations. Pas d'accès comptabilité |

- Invitation par **code QR** ou **lien SMS**
- Chaque compte lié à un **Google Account** via Supabase Auth
- Les données de chaque ferme sont isolées par `user_id` (Row Level Security Supabase)

---

## 7. Design system

### 7.1 Palette de couleurs

| Module | Couleur | HEX | Usage |
|---|---|---|---|
| Production / Lapins | Vert teal | `#1D9E75` | En-têtes, boutons principaux, dashboard |
| Saillie / Reproduction | Violet | `#7F77DD` | Formulaires saillie, badges maternité |
| Vente / Comptabilité | Ambre | `#BA7517` | Écran vente, badges "à vendre" |
| Matériel / Stock | Corail | `#D85A30` | Alertes stock, équipements |
| Santé / Vétérinaire | Vert foncé | `#0F6E56` | Traitements, vaccins |
| Alertes urgentes | Rouge | `#E24B4A` | Mortalité, stock critique |
| Neutre / Système | Gris | `#888780` | Textes secondaires, séparateurs |

### 7.2 Typographie

| Élément | Taille | Poids |
|---|---|---|
| Titre écran | 19px | 500 |
| Labels de sections | 11px | 500 / uppercase |
| Corps de texte | 13px | 400 |
| Sous-titres et meta | 11px | 400 / couleur secondaire |
| Valeurs KPI | 22px | 500 |

### 7.3 Composants UI récurrents

- **KpiCard** : fond secondaire, label 11px au-dessus, valeur 22px, indicateur coloré
- **NotifItem** : icône colorée 34px, titre 12px/500, sous-titre 11px, date 10px
- **Timeline** : point coloré + ligne verticale + corps de texte à droite
- **LotBadge** : pill colorée selon stade (vert / violet / ambre)
- **ActionButton** : plein pour action principale, bordure pour action secondaire
- **Sélecteur 3 options** : `Réussie` / `Douteuse` / `Échouée` pour résultat saillie

---

## 8. Priorités

### Phase 1 — MVP (démarrer ici)

- [ ] Setup Flutter + Dart + structure de dossiers de la section 5.3
- [ ] Configurer **pubspec.yaml** : drift, sqflite, riverpod, go_router, supabase_flutter, google_sign_in, flutter_local_notifications, fl_chart, flutter_localizations, intl, pdf, printing, share_plus
- [ ] Configurer le projet **Supabase** : créer les tables avec Row Level Security (RLS)
- [ ] Écran de connexion **Google Sign-In** via Supabase Auth (section 4.0)
- [ ] Configurer **GoRouter** + guard de navigation (redirige vers login si non connecté)
- [ ] Configurer **drift** avec le schéma local complet (voir section 2)
- [ ] Configurer **flutter_localizations** + fichiers `app_fr.arb` / `app_en.arb`
- [ ] Implémenter `calculations.dart` : calculs automatiques de dates
- [ ] Écran 1 : Tableau de bord avec KPI et alertes du jour
- [ ] Écran 2 : Liste des lapins + fiche individuelle avec timeline
- [ ] Écran 3 : Formulaire de saisie d'une saillie
- [ ] Configurer **flutter_local_notifications** : routine matin + événements stade

### Phase 2 — Fonctions core

- [ ] Écran de vente avec génération automatique de transaction
- [ ] Gestion des lots et des cages
- [ ] Saisie des pesées et courbe de croissance
- [ ] Gestion du stock avec alertes automatiques
- [ ] Traitement sanitaire et rappels vaccins

### Phase 3 — Avancé

- [ ] Écran Rapports avec **fl_chart** et export PDF (**pdf** + **printing**)
- [ ] Gestion multi-utilisateurs (rôles propriétaire / ouvrier) via Supabase RLS
- [ ] Synchronisation temps réel avec **Supabase Realtime** (multi-appareils)
- [ ] Collecte de données JSON pour modélisation / IA future
- [ ] Bon de vente PDF partagé par WhatsApp ou SMS (**share_plus**)

---

## 9. Prompt Claude Code

Copiez-collez ce prompt dans Claude Code pour démarrer le développement :

```
Je veux que tu développes CuniGest, une application mobile Flutter (Dart)
de gestion de ferme cunicole bilangue (Français/Anglais) pour des cuniculteurs
en Afrique.

Le cahier des charges complet est dans ce fichier Markdown.

Commence par :
1. Créer le projet Flutter avec la structure de dossiers de la section 5.3
2. Configurer pubspec.yaml avec les dépendances : drift, sqflite, riverpod,
   go_router, supabase_flutter, google_sign_in, flutter_local_notifications,
   fl_chart, flutter_localizations, intl, pdf, printing, share_plus,
   connectivity_plus, workmanager
3. Configurer Supabase : créer le fichier supabase/migrations/001_initial_schema.sql
   avec toutes les tables de la section 2 + Row Level Security (RLS) par user_id
4. Implémenter l'écran de connexion Google (section 4.0) via Supabase Auth
5. Configurer GoRouter avec un auth guard : redirection vers login si non connecté
6. Créer drift app_database.dart avec le schéma local complet (section 2)
7. Créer core/utils/calculations.dart avec les calculs automatiques (section 6.1)
8. Implémenter le tableau de bord (section 4.1) avec données en dur pour tester l'UI

Contraintes importantes :
- **OFFLINE-FIRST** : L'app doit fonctionner à 100% sans connexion. SQLite (drift)
  est la source de vérité principale. Implémenter SyncQueue (table locale) +
  SyncManager + ConnectivityService dès le départ (voir section 5.2)
- Chaque table doit avoir les champs : id, user_id, created_at, updated_at,
  deleted_at (soft delete), is_synced
- Utilise connectivity_plus pour détecter le retour de connexion et déclencher
  la synchronisation automatiquement
- Indicateur visuel de sync dans l'UI (point vert/jaune/rouge)
- Utilise la palette de couleurs de la section 7 (#1D9E75 vert principal)
  dans core/theme/app_theme.dart
- Tout fonctionne hors ligne (drift/sqflite local, flutter_local_notifications)
- Synchronisation automatique locale ↔ Supabase cloud quand connexion disponible
- Chaque enregistrement dans Supabase doit avoir un champ user_id lié au compte Google
- Interface bilangue FR/EN avec flutter_localizations (app_fr.arb / app_en.arb)
- Architecture feature-first comme décrit en section 5.3
- Riverpod pour la gestion d'état, GoRouter pour la navigation
```

---

*CuniGest v1.2 — Cahier des charges complet — Flutter / Supabase / Google Auth / Offline-First — Mai 2025*
