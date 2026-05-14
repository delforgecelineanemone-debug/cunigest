// ──────────────────────────────────────────────────────────────
// Schéma & migrations SQLite — CuniGest (extraction depuis db_helper)
// ──────────────────────────────────────────────────────────────
// Fonctions top-level testables sans SQLCipher : prennent un objet
// `Database` (sqflite/sqflite_sqlcipher/sqflite_common_ffi compatibles)
// et appliquent la création initiale, le seed, ou les migrations.
//
// IMPORTANT : toute modif de schéma → incrémenter `kCurrentDbVersion`
// ET ajouter une branche `oldVersion < N` dans `upgradeSchema`.
// ──────────────────────────────────────────────────────────────

import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/reglages.dart';
import '../utils/app_config.dart';

/// Version courante du schéma de base de données.
const int kCurrentDbVersion = 15;

/// Active les contraintes de clés étrangères (SQLite les ignore par défaut).
Future<void> onConfigureSchema(Database db) async {
  await db.execute('PRAGMA foreign_keys = ON');
}

/// Crée toutes les tables et index dans une base vide (premier lancement).
/// Appelé depuis `onCreate` de openDatabase.
Future<void> createSchema(Database db, int version) async {
  // Table des lapins (avec généalogie + cage_id + photo_path V2.2)
  await db.execute('''
    CREATE TABLE lapins (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      numero_bague TEXT NOT NULL,
      nom TEXT,
      sexe TEXT NOT NULL,
      race TEXT,
      date_naissance TEXT,
      poids REAL,
      couleur TEXT,
      statut TEXT DEFAULT 'actif',
      cage TEXT,
      cage_id INTEGER,
      photo_path TEXT,
      prix_achat REAL,
      destination TEXT,
      notes TEXT,
      pere_id INTEGER,
      mere_id INTEGER,
      date_creation TEXT NOT NULL,
      FOREIGN KEY (pere_id) REFERENCES lapins(id) ON DELETE SET NULL,
      FOREIGN KEY (mere_id) REFERENCES lapins(id) ON DELETE SET NULL,
      FOREIGN KEY (cage_id) REFERENCES cages(id) ON DELETE SET NULL
    )
  ''');
  await db.execute('CREATE INDEX idx_lapins_cage ON lapins(cage_id)');
  await db.execute('CREATE UNIQUE INDEX idx_lapins_numero_bague ON lapins(numero_bague)');
  await db.execute('CREATE INDEX idx_lapins_statut ON lapins(statut)');
  await db.execute('CREATE INDEX idx_lapins_sexe ON lapins(sexe)');

  // Table des saillies (reproduction)
  await db.execute('''
    CREATE TABLE saillies (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      mere_id INTEGER NOT NULL,
      pere_id INTEGER NOT NULL,
      date_saillie TEXT NOT NULL,
      date_mise_bas_prevue TEXT,
      date_mise_bas_reelle TEXT,
      nb_nes INTEGER,
      nb_vivants INTEGER,
      nb_morts INTEGER,
      nb_sevres INTEGER,
      date_sevrage TEXT,
      poids_sevrage_total REAL,
      statut TEXT DEFAULT 'en_attente',
      palpation_positive INTEGER DEFAULT 0,
      nb_chevauchements INTEGER,
      etat_nid TEXT,
      notes TEXT,
      lot_id INTEGER,
      FOREIGN KEY (mere_id) REFERENCES lapins(id),
      FOREIGN KEY (pere_id) REFERENCES lapins(id),
      FOREIGN KEY (lot_id) REFERENCES lots(id) ON DELETE SET NULL
    )
  ''');
  await db.execute('CREATE INDEX idx_saillies_mere ON saillies(mere_id)');
  await db.execute('CREATE INDEX idx_saillies_statut ON saillies(statut)');

  // Table des soins et vaccinations
  await db.execute('''
    CREATE TABLE soins (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      lapin_id INTEGER,
      type_soin TEXT NOT NULL,
      date_soin TEXT NOT NULL,
      date_rappel TEXT,
      produit TEXT,
      dose TEXT,
      veterinaire TEXT,
      cout REAL,
      delai_attente_jours INTEGER,
      notes TEXT,
      FOREIGN KEY (lapin_id) REFERENCES lapins(id) ON DELETE CASCADE
    )
  ''');
  await db.execute('CREATE INDEX idx_soins_lapin ON soins(lapin_id)');
  await db.execute('CREATE INDEX idx_soins_date_rappel ON soins(date_rappel)');

  // Table des stocks (alimentation et produits)
  await db.execute('''
    CREATE TABLE stocks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      produit TEXT NOT NULL,
      type_aliment TEXT NOT NULL,
      quantite REAL NOT NULL,
      unite TEXT NOT NULL,
      quantite_min REAL DEFAULT 0,
      date_entree TEXT,
      date_expiration TEXT,
      fournisseur TEXT,
      cout_unitaire REAL,
      notes TEXT
    )
  ''');

  // Table des consommations de stock
  await db.execute('''
    CREATE TABLE consommations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      stock_id INTEGER NOT NULL,
      quantite REAL NOT NULL,
      date_consommation TEXT NOT NULL,
      notes TEXT,
      FOREIGN KEY (stock_id) REFERENCES stocks(id) ON DELETE CASCADE
    )
  ''');

  // Table des ventes
  await db.execute('''
    CREATE TABLE ventes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      lapin_id INTEGER,
      lot_id INTEGER,
      date_vente TEXT NOT NULL,
      type_vente TEXT NOT NULL,
      acheteur TEXT,
      prix_vente REAL NOT NULL,
      poids REAL,
      quantite INTEGER DEFAULT 1,
      notes TEXT,
      FOREIGN KEY (lapin_id) REFERENCES lapins(id) ON DELETE SET NULL,
      FOREIGN KEY (lot_id) REFERENCES lots(id) ON DELETE SET NULL
    )
  ''');
  await db.execute('CREATE INDEX idx_ventes_date ON ventes(date_vente)');

  // Table des tâches quotidiennes (système de routines)
  await db.execute('''
    CREATE TABLE taches_quotidiennes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      titre TEXT NOT NULL,
      description TEXT,
      categorie TEXT NOT NULL,
      priorite TEXT DEFAULT 'normal',
      recurrence TEXT DEFAULT 'quotidien',
      heure_rappel TEXT,
      est_active INTEGER DEFAULT 1,
      est_systeme INTEGER DEFAULT 0,
      reference_id INTEGER,
      reference_type TEXT,
      points INTEGER DEFAULT 10,
      date_creation TEXT NOT NULL,
      date_echeance TEXT,
      statut TEXT DEFAULT 'en_attente',
      exceptions TEXT
    )
  ''');

  // Table des complétions de tâches (historique)
  await db.execute('''
    CREATE TABLE completions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tache_id INTEGER NOT NULL,
      date_completion TEXT NOT NULL,
      heure_completion TEXT,
      notes TEXT,
      FOREIGN KEY (tache_id) REFERENCES taches_quotidiennes(id) ON DELETE CASCADE
    )
  ''');
  await db.execute('CREATE INDEX idx_completions_date ON completions(date_completion)');
  await db.execute('CREATE INDEX idx_completions_tache ON completions(tache_id)');

  // Table des alertes (notifications intelligentes)
  await db.execute('''
    CREATE TABLE alertes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      titre TEXT NOT NULL,
      message TEXT,
      priorite TEXT DEFAULT 'normal',
      date_alerte TEXT NOT NULL,
      est_lue INTEGER DEFAULT 0,
      est_traitee INTEGER DEFAULT 0,
      reference_id INTEGER,
      reference_type TEXT
    )
  ''');
  await db.execute('CREATE INDEX idx_alertes_traitee ON alertes(est_traitee, date_alerte)');

  // Table du profil éleveur (gamification)
  await db.execute('''
    CREATE TABLE profil_eleveur (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      streak_actuel INTEGER DEFAULT 0,
      meilleur_streak INTEGER DEFAULT 0,
      score_total INTEGER DEFAULT 0,
      score_aujourdhui INTEGER DEFAULT 0,
      niveau INTEGER DEFAULT 1,
      derniere_activite TEXT,
      date_creation TEXT NOT NULL
    )
  ''');

  // Table des badges (récompenses)
  await db.execute('''
    CREATE TABLE badges (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      code TEXT NOT NULL UNIQUE,
      nom TEXT NOT NULL,
      description TEXT,
      icone TEXT,
      date_obtenu TEXT
    )
  ''');

  // Table des réglages (singleton, id=1)
  await db.execute('''
    CREATE TABLE reglages (
      id INTEGER PRIMARY KEY,
      gamification_active INTEGER DEFAULT 1,
      tolerance_streak_jours INTEGER DEFAULT 1,
      heure_rappel_matin TEXT DEFAULT '07:00',
      heure_rappel_midi TEXT DEFAULT '12:00',
      heure_rappel_soir TEXT DEFAULT '18:00',
      notifications_actives INTEGER DEFAULT 1,
      theme_mode TEXT DEFAULT 'system',
      onboarding_done INTEGER DEFAULT 0,
      devise TEXT DEFAULT '€',
      mode_soleil INTEGER DEFAULT 0,
      mode_gants INTEGER DEFAULT 0
    )
  ''');

  // ── V5 : lots, sync_queue, sync_config, users ──
  await createV5Tables(db);

  // ── V7 : bâtiments / clapiers / cages / mouvements ──
  await createV7Tables(db);

  // ── V9 : pesées individuelles + dépenses ──
  await createV9Tables(db);
}

/// Crée les tables ajoutées en V9 (Phase 4 — pesées indiv. + finances).
Future<void> createV9Tables(Database db) async {
  await db.execute('''
    CREATE TABLE pesees_lapin (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      lapin_id INTEGER NOT NULL,
      date_pesee TEXT NOT NULL,
      poids REAL NOT NULL,
      notes TEXT,
      FOREIGN KEY (lapin_id) REFERENCES lapins(id) ON DELETE CASCADE
    )
  ''');
  await db.execute('CREATE INDEX idx_pesees_lapin_lapin ON pesees_lapin(lapin_id)');
  await db.execute('CREATE INDEX idx_pesees_lapin_date ON pesees_lapin(date_pesee)');

  await db.execute('''
    CREATE TABLE depenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date_depense TEXT NOT NULL,
      categorie TEXT NOT NULL,
      montant REAL NOT NULL,
      description TEXT,
      notes TEXT,
      lot_id INTEGER,
      lapin_id INTEGER,
      date_creation TEXT NOT NULL,
      FOREIGN KEY (lot_id) REFERENCES lots(id) ON DELETE SET NULL,
      FOREIGN KEY (lapin_id) REFERENCES lapins(id) ON DELETE SET NULL
    )
  ''');
  await db.execute('CREATE INDEX idx_depenses_date ON depenses(date_depense)');
  await db.execute('CREATE INDEX idx_depenses_categorie ON depenses(categorie)');
}

/// Crée les tables ajoutées en V7 (Phase 2 — module cages).
/// Hiérarchie : Bâtiment → Clapier → Cage → Lapin(s).
Future<void> createV7Tables(Database db) async {
  await db.execute('''
    CREATE TABLE batiments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nom TEXT NOT NULL,
      adresse TEXT,
      notes TEXT,
      date_creation TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE clapiers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nom TEXT NOT NULL,
      batiment_id INTEGER NOT NULL,
      notes TEXT,
      date_creation TEXT NOT NULL,
      FOREIGN KEY (batiment_id) REFERENCES batiments(id) ON DELETE CASCADE
    )
  ''');
  await db.execute('CREATE INDEX idx_clapiers_batiment ON clapiers(batiment_id)');

  await db.execute('''
    CREATE TABLE cages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      numero TEXT NOT NULL,
      clapier_id INTEGER NOT NULL,
      capacite_max INTEGER NOT NULL DEFAULT 1,
      statut TEXT NOT NULL DEFAULT 'vide',
      notes TEXT,
      date_creation TEXT NOT NULL,
      FOREIGN KEY (clapier_id) REFERENCES clapiers(id) ON DELETE CASCADE
    )
  ''');
  await db.execute('CREATE UNIQUE INDEX idx_cages_numero ON cages(numero)');
  await db.execute('CREATE INDEX idx_cages_clapier ON cages(clapier_id)');
  await db.execute('CREATE INDEX idx_cages_statut ON cages(statut)');

  await db.execute('''
    CREATE TABLE mouvements_cage (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      lapin_id INTEGER NOT NULL,
      cage_origine_id INTEGER,
      cage_destination_id INTEGER,
      date TEXT NOT NULL,
      motif TEXT,
      notes TEXT,
      FOREIGN KEY (lapin_id) REFERENCES lapins(id) ON DELETE CASCADE,
      FOREIGN KEY (cage_origine_id) REFERENCES cages(id) ON DELETE SET NULL,
      FOREIGN KEY (cage_destination_id) REFERENCES cages(id) ON DELETE SET NULL
    )
  ''');
  await db.execute('CREATE INDEX idx_mvt_lapin ON mouvements_cage(lapin_id, date)');
  await db.execute('CREATE INDEX idx_mvt_cage_dest ON mouvements_cage(cage_destination_id)');
  await db.execute('CREATE INDEX idx_mvt_cage_orig ON mouvements_cage(cage_origine_id)');
}

/// Crée les tables ajoutées en V5 (lots d'engraissement, sync, users)
Future<void> createV5Tables(Database db) async {
  // Lots d'engraissement
  // V13 : ajout saillie_id (lien vers la saillie d'origine si auto-créé).
  // Statut peut prendre : 'en_cours', 'individualise' (V13 — lapereaux baguer
  // individuellement après sexage à J+60), 'termine'.
  await db.execute('''
    CREATE TABLE lots (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      code TEXT NOT NULL UNIQUE,
      date_creation TEXT NOT NULL,
      cage TEXT,
      nombre_initial INTEGER NOT NULL,
      poids_initial REAL,
      statut TEXT DEFAULT 'en_cours',
      date_fin TEXT,
      notes TEXT,
      saillie_id INTEGER,
      FOREIGN KEY (saillie_id) REFERENCES saillies(id) ON DELETE SET NULL
    )
  ''');
  await db.execute('CREATE INDEX idx_lots_statut ON lots(statut)');

  // Pesées de contrôle
  await db.execute('''
    CREATE TABLE pesees (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      lot_id INTEGER NOT NULL,
      date_pesee TEXT NOT NULL,
      poids_total REAL NOT NULL,
      nombre INTEGER NOT NULL,
      notes TEXT,
      FOREIGN KEY (lot_id) REFERENCES lots(id) ON DELETE CASCADE
    )
  ''');
  await db.execute('CREATE INDEX idx_pesees_lot ON pesees(lot_id, date_pesee)');

  // Distributions d'aliment (pour calcul IC)
  await db.execute('''
    CREATE TABLE distributions_aliment (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      lot_id INTEGER NOT NULL,
      stock_id INTEGER,
      date_distribution TEXT NOT NULL,
      quantite_kg REAL NOT NULL,
      notes TEXT,
      FOREIGN KEY (lot_id) REFERENCES lots(id) ON DELETE CASCADE,
      FOREIGN KEY (stock_id) REFERENCES stocks(id) ON DELETE SET NULL
    )
  ''');
  await db.execute('CREATE INDEX idx_distributions_lot ON distributions_aliment(lot_id)');

  // Liaison lapins ↔ lots (un lapereau peut être membre d'un lot)
  await db.execute('''
    CREATE TABLE lot_lapins (
      lot_id INTEGER NOT NULL,
      lapin_id INTEGER NOT NULL,
      date_entree TEXT NOT NULL,
      date_sortie TEXT,
      motif_sortie TEXT,
      PRIMARY KEY (lot_id, lapin_id),
      FOREIGN KEY (lot_id) REFERENCES lots(id) ON DELETE CASCADE,
      FOREIGN KEY (lapin_id) REFERENCES lapins(id) ON DELETE CASCADE
    )
  ''');

  // File de synchronisation cloud
  await db.execute('''
    CREATE TABLE sync_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      table_name TEXT NOT NULL,
      row_id INTEGER NOT NULL,
      operation TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      created_at TEXT NOT NULL,
      synced_at TEXT,
      error_message TEXT,
      retry_count INTEGER DEFAULT 0
    )
  ''');
  await db.execute('CREATE INDEX idx_sync_pending ON sync_queue(synced_at)');

  // Configuration de synchronisation + compte unique (singleton id=1)
  // V11 : password_hash et nom ajoutés pour le compte cuniculteur unique.
  await db.execute('''
    CREATE TABLE sync_config (
      id INTEGER PRIMARY KEY,
      enabled INTEGER DEFAULT 1,
      server_url TEXT,
      api_key TEXT,
      user_id TEXT,
      email TEXT,
      password_hash TEXT,
      nom TEXT,
      access_token TEXT,
      refresh_token TEXT,
      last_sync_at TEXT
    )
  ''');
  // Pré-remplir avec le projet Supabase de l'éleveur (URL + anon key)
  // L'utilisateur active la sync depuis Réglages → Sync.
  await db.insert('sync_config', {
    'id': 1,
    'enabled': 0,
    'server_url': AppConfig.supabaseUrl,
    'api_key': AppConfig.supabaseAnonKey,
  });

  // Utilisateurs (multi-utilisateur local)
  await db.execute('''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nom TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'admin',
      pin_hash TEXT NOT NULL,
      date_creation TEXT NOT NULL,
      derniere_connexion TEXT
    )
  ''');
  await db.execute('CREATE UNIQUE INDEX idx_users_nom ON users(nom)');
}

/// Insère les données par défaut (profil, tâches, réglages).
Future<void> seedInitialData(Database db) async {
  final now = DateTime.now().toIso8601String().substring(0, 10);

  await db.insert('profil_eleveur', {
    'streak_actuel': 0,
    'meilleur_streak': 0,
    'score_total': 0,
    'score_aujourdhui': 0,
    'niveau': 1,
    'date_creation': now,
  });

  await db.insert('reglages', const Reglages().toMap());

  final tachesDefaut = [
    {'titre': 'Nourrir les lapins', 'categorie': 'nourriture', 'priorite': 'critique', 'recurrence': 'quotidien', 'heure_rappel': '07:00', 'est_systeme': 1, 'points': 30},
    {'titre': "Vérifier l'eau", 'categorie': 'eau', 'priorite': 'critique', 'recurrence': 'quotidien', 'heure_rappel': '07:00', 'est_systeme': 1, 'points': 30},
    {'titre': 'Observation générale', 'categorie': 'observation', 'priorite': 'important', 'recurrence': 'quotidien', 'heure_rappel': '08:00', 'est_systeme': 1, 'points': 20},
    {'titre': 'Nettoyage des cages', 'categorie': 'nettoyage', 'priorite': 'important', 'recurrence': 'hebdomadaire', 'heure_rappel': '09:00', 'est_systeme': 1, 'points': 20},
    {'titre': 'Vérifier les stocks', 'categorie': 'observation', 'priorite': 'normal', 'recurrence': 'hebdomadaire', 'heure_rappel': '10:00', 'est_systeme': 1, 'points': 10},
  ];
  for (final t in tachesDefaut) {
    await db.insert('taches_quotidiennes', {
      ...t,
      'est_active': 1,
      'date_creation': now,
    });
  }
}

/// Ajoute une colonne via ALTER TABLE.
/// Ignore silencieusement "duplicate column name" (colonne déjà présente).
/// Toute autre DatabaseException (table inexistante, syntaxe) est relancée.
Future<void> _addColumn(Database db, String sql) async {
  try {
    await db.execute(sql);
  } on DatabaseException catch (e) {
    if (!e.toString().contains('duplicate column')) rethrow;
  }
}

/// Migration de base de données lors d'une mise à jour.
/// Permet d'ajouter de nouvelles tables/colonnes sans perdre les données.
///
/// IMPORTANT : les blocs doivent rester en ordre croissant de version.
/// Un bloc hors-ordre peut s'exécuter APRÈS un bloc qui dépend de ses colonnes.
Future<void> upgradeSchema(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ventes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lapin_id INTEGER,
        date_vente TEXT NOT NULL,
        type_vente TEXT NOT NULL,
        acheteur TEXT,
        prix_vente REAL NOT NULL,
        poids REAL,
        quantite INTEGER DEFAULT 1,
        notes TEXT,
        FOREIGN KEY (lapin_id) REFERENCES lapins(id)
      )
    ''');
  }

  if (oldVersion < 3) {
    // Version 3 : Routines, alertes, gamification
    await db.execute("CREATE TABLE IF NOT EXISTS taches_quotidiennes (id INTEGER PRIMARY KEY AUTOINCREMENT, titre TEXT NOT NULL, description TEXT, categorie TEXT NOT NULL, priorite TEXT DEFAULT 'normal', recurrence TEXT DEFAULT 'quotidien', heure_rappel TEXT, est_active INTEGER DEFAULT 1, est_systeme INTEGER DEFAULT 0, reference_id INTEGER, reference_type TEXT, points INTEGER DEFAULT 10, date_creation TEXT NOT NULL)");
    await db.execute('CREATE TABLE IF NOT EXISTS completions (id INTEGER PRIMARY KEY AUTOINCREMENT, tache_id INTEGER NOT NULL, date_completion TEXT NOT NULL, heure_completion TEXT, notes TEXT, FOREIGN KEY (tache_id) REFERENCES taches_quotidiennes(id))');
    await db.execute("CREATE TABLE IF NOT EXISTS alertes (id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, titre TEXT NOT NULL, message TEXT, priorite TEXT DEFAULT 'normal', date_alerte TEXT NOT NULL, est_lue INTEGER DEFAULT 0, est_traitee INTEGER DEFAULT 0, reference_id INTEGER, reference_type TEXT)");
    await db.execute('CREATE TABLE IF NOT EXISTS profil_eleveur (id INTEGER PRIMARY KEY AUTOINCREMENT, streak_actuel INTEGER DEFAULT 0, meilleur_streak INTEGER DEFAULT 0, score_total INTEGER DEFAULT 0, score_aujourdhui INTEGER DEFAULT 0, niveau INTEGER DEFAULT 1, derniere_activite TEXT, date_creation TEXT NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS badges (id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT NOT NULL UNIQUE, nom TEXT NOT NULL, description TEXT, icone TEXT, date_obtenu TEXT)');

    final now = DateTime.now().toIso8601String().substring(0, 10);
    final existing = await db.query('profil_eleveur');
    if (existing.isEmpty) {
      await db.insert('profil_eleveur', {
        'streak_actuel': 0, 'meilleur_streak': 0, 'score_total': 0,
        'score_aujourdhui': 0, 'niveau': 1, 'date_creation': now,
      });
    }
    final existingTaches = await db.query('taches_quotidiennes');
    if (existingTaches.isEmpty) {
      await db.insert('taches_quotidiennes', {'titre': 'Nourrir les lapins', 'categorie': 'nourriture', 'priorite': 'critique', 'recurrence': 'quotidien', 'heure_rappel': '07:00', 'est_active': 1, 'est_systeme': 1, 'points': 30, 'date_creation': now});
      await db.insert('taches_quotidiennes', {'titre': "Vérifier l'eau", 'categorie': 'eau', 'priorite': 'critique', 'recurrence': 'quotidien', 'heure_rappel': '07:00', 'est_active': 1, 'est_systeme': 1, 'points': 30, 'date_creation': now});
      await db.insert('taches_quotidiennes', {'titre': 'Observation générale', 'categorie': 'observation', 'priorite': 'important', 'recurrence': 'quotidien', 'heure_rappel': '08:00', 'est_active': 1, 'est_systeme': 1, 'points': 20, 'date_creation': now});
      await db.insert('taches_quotidiennes', {'titre': 'Nettoyage des cages', 'categorie': 'nettoyage', 'priorite': 'important', 'recurrence': 'hebdomadaire', 'heure_rappel': '09:00', 'est_active': 1, 'est_systeme': 1, 'points': 20, 'date_creation': now});
      await db.insert('taches_quotidiennes', {'titre': 'Vérifier les stocks', 'categorie': 'observation', 'priorite': 'normal', 'recurrence': 'hebdomadaire', 'heure_rappel': '10:00', 'est_active': 1, 'est_systeme': 1, 'points': 10, 'date_creation': now});
    }
  }

  if (oldVersion < 4) {
    // Version 4 : généalogie, délai d'attente médicaments, stats reproduction, réglages

    // 1. Lapins : pere_id, mere_id + UNIQUE numero_bague
    await db.execute('ALTER TABLE lapins ADD COLUMN pere_id INTEGER');
    await db.execute('ALTER TABLE lapins ADD COLUMN mere_id INTEGER');

    // Dédupliquer les numero_bague existants AVANT de créer l'index UNIQUE
    // (sinon la migration échoue si des doublons existent)
    await db.execute('''
      UPDATE lapins
      SET numero_bague = numero_bague || '_dup' || id
      WHERE id IN (
        SELECT l1.id FROM lapins l1
        WHERE EXISTS (
          SELECT 1 FROM lapins l2
          WHERE l2.numero_bague = l1.numero_bague AND l2.id < l1.id
        )
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_lapins_numero_bague ON lapins(numero_bague)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_lapins_statut ON lapins(statut)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_lapins_sexe ON lapins(sexe)');

    // 2. Soins : délai d'attente
    await db.execute('ALTER TABLE soins ADD COLUMN delai_attente_jours INTEGER');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_soins_lapin ON soins(lapin_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_soins_date_rappel ON soins(date_rappel)');

    // 3. Saillies : stats reproduction
    await db.execute('ALTER TABLE saillies ADD COLUMN nb_morts INTEGER');
    await db.execute('ALTER TABLE saillies ADD COLUMN date_sevrage TEXT');
    await db.execute('ALTER TABLE saillies ADD COLUMN poids_sevrage_total REAL');
    await db.execute('ALTER TABLE saillies ADD COLUMN palpation_positive INTEGER DEFAULT 0');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_saillies_mere ON saillies(mere_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_saillies_statut ON saillies(statut)');

    // 4. Ventes : index date
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ventes_date ON ventes(date_vente)');

    // 5. Alertes : index priorité
    await db.execute('CREATE INDEX IF NOT EXISTS idx_alertes_traitee ON alertes(est_traitee, date_alerte)');

    // 6. Complétions : index dates
    await db.execute('CREATE INDEX IF NOT EXISTS idx_completions_date ON completions(date_completion)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_completions_tache ON completions(tache_id)');

    // 7. Table reglages
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reglages (
        id INTEGER PRIMARY KEY,
        gamification_active INTEGER DEFAULT 1,
        tolerance_streak_jours INTEGER DEFAULT 1,
        heure_rappel_matin TEXT DEFAULT '07:00',
        heure_rappel_midi TEXT DEFAULT '12:00',
        heure_rappel_soir TEXT DEFAULT '18:00',
        notifications_actives INTEGER DEFAULT 1
      )
    ''');
    final existingReglages = await db.query('reglages');
    if (existingReglages.isEmpty) {
      // À l'époque de v4, le modèle Reglages avait moins de colonnes.
      // On insère uniquement les champs alors présents — les colonnes
      // ajoutées plus tard (theme_mode v8, onboarding_done v8, devise v10)
      // recevront leur DEFAULT via les ALTER TABLE des migrations suivantes.
      await db.insert('reglages', {
        'id': 1,
        'gamification_active': 1,
        'tolerance_streak_jours': 1,
        'heure_rappel_matin': '07:00',
        'heure_rappel_midi': '12:00',
        'heure_rappel_soir': '18:00',
        'notifications_actives': 1,
      });
    }
  }

  if (oldVersion < 5) {
    // Version 5 : lots d'engraissement, sync cloud, multi-utilisateur
    await createV5Tables(db);
  }

  if (oldVersion < 6) {
    // Version 6 : auth Supabase (email + tokens) dans sync_config.
    // DOIT être après v5 (qui crée sync_config) et AVANT v7+.
    await _addColumn(db, 'ALTER TABLE sync_config ADD COLUMN email TEXT');
    await _addColumn(db, 'ALTER TABLE sync_config ADD COLUMN access_token TEXT');
    await _addColumn(db, 'ALTER TABLE sync_config ADD COLUMN refresh_token TEXT');

    // Pré-remplir la config Supabase si elle est injectée au build.
    // Pas de fallback hardcodé : une build sans --dart-define reste offline.
    final existing = await db.query('sync_config', where: 'id = 1');
    final hasBuildConfig =
        AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty;
    if (hasBuildConfig && (existing.isEmpty || (existing.first['server_url'] == null))) {
      await db.update(
        'sync_config',
        {
          'server_url': AppConfig.supabaseUrl,
          'api_key': AppConfig.supabaseAnonKey,
        },
        where: 'id = 1',
      );
      if (existing.isEmpty) {
        await db.insert('sync_config', {
          'id': 1,
          'enabled': 0,
          'server_url': AppConfig.supabaseUrl,
          'api_key': AppConfig.supabaseAnonKey,
        });
      }
    }
  }

  if (oldVersion < 7) {
    // Version 7 : module Cages (Phase 2) — bâtiments, clapiers, cages, mouvements
    // + colonnes cage_id et photo_path sur lapins (cage TEXT préservé pour legacy).
    await createV7Tables(db);
    await _addColumn(db, 'ALTER TABLE lapins ADD COLUMN cage_id INTEGER REFERENCES cages(id) ON DELETE SET NULL');
    await _addColumn(db, 'ALTER TABLE lapins ADD COLUMN photo_path TEXT');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_lapins_cage ON lapins(cage_id)');
  }

  if (oldVersion < 8) {
    // Version 8 : Phase 3 — préférences de thème + flag onboarding.
    await _addColumn(db, "ALTER TABLE reglages ADD COLUMN theme_mode TEXT DEFAULT 'system'");
    await _addColumn(db, 'ALTER TABLE reglages ADD COLUMN onboarding_done INTEGER DEFAULT 0');
  }

  if (oldVersion < 9) {
    // Version 9 : Phase 4 — pesées individuelles, dépenses, tâches avancées.
    await createV9Tables(db);
    await _addColumn(db, 'ALTER TABLE taches_quotidiennes ADD COLUMN date_echeance TEXT');
    await _addColumn(db, "ALTER TABLE taches_quotidiennes ADD COLUMN statut TEXT DEFAULT 'en_attente'");
    await _addColumn(db, 'ALTER TABLE taches_quotidiennes ADD COLUMN exceptions TEXT');
  }

  if (oldVersion < 10) {
    // Version 10 : devise configurable.
    await _addColumn(db, "ALTER TABLE reglages ADD COLUMN devise TEXT DEFAULT '€'");
    if (!AppConfig.hasSupabaseDefaults) {
      await db.update(
        'sync_config',
        {'server_url': '', 'api_key': ''},
        where: "api_key LIKE 'eyJ%'",
      );
    }
  }

  if (oldVersion < 11) {
    // Version 11 : compte unique cuniculteur lié au cloud.
    // sync_config devient la source de vérité du compte (singleton id=1).
    await _addColumn(db, 'ALTER TABLE sync_config ADD COLUMN password_hash TEXT');
    await _addColumn(db, 'ALTER TABLE sync_config ADD COLUMN nom TEXT');
    // La sync est désormais "toujours active" par défaut quand un compte
    // existe — l'utilisateur n'a plus à l'activer manuellement.
    await db.update('sync_config', {'enabled': 1});
  }

  if (oldVersion < 12) {
    // Version 12 : rentabilité par lot + par animal (Phase 4).
    // Imputation directe des dépenses ET des ventes sur un lot
    // ou un lapin + prix d'achat des reproducteurs (tous optionnels).
    await _addColumn(db, 'ALTER TABLE depenses ADD COLUMN lot_id INTEGER');
    await _addColumn(db, 'ALTER TABLE depenses ADD COLUMN lapin_id INTEGER');
    await _addColumn(db, 'ALTER TABLE ventes ADD COLUMN lot_id INTEGER');
    await _addColumn(db, 'ALTER TABLE lapins ADD COLUMN prix_achat REAL');
  }

  if (oldVersion < 13) {
    // Version 13 : auto-création du lot depuis la mise bas + sexage J+60.
    // Lien bidirectionnel saillies.lot_id ↔ lots.saillie_id.
    await _addColumn(db, 'ALTER TABLE saillies ADD COLUMN lot_id INTEGER');
    await _addColumn(db, 'ALTER TABLE lots ADD COLUMN saillie_id INTEGER');
  }

  if (oldVersion < 14) {
    // Version 14 : workflow cuniculture conforme (Phase 4.5)
    // - saillies.nb_chevauchements : nombre de saillies réussies à J0
    // - saillies.etat_nid : observation à J+28 (préparation nid mise bas)
    // - lapins.destination : sortie de ferme (vendu/consomme/reproducteur/autre)
    await _addColumn(db, 'ALTER TABLE saillies ADD COLUMN nb_chevauchements INTEGER');
    await _addColumn(db, 'ALTER TABLE saillies ADD COLUMN etat_nid TEXT');
    await _addColumn(db, 'ALTER TABLE lapins ADD COLUMN destination TEXT');
  }

  if (oldVersion < 15) {
    // Version 15 : Phase R5 — modes d'accessibilité terrain.
    // mode_soleil : texte +25%, thème forcé clair (lisibilité plein soleil)
    // mode_gants  : cibles tactiles agrandies +15% (utilisation avec gants)
    await _addColumn(db, 'ALTER TABLE reglages ADD COLUMN mode_soleil INTEGER DEFAULT 0');
    await _addColumn(db, 'ALTER TABLE reglages ADD COLUMN mode_gants INTEGER DEFAULT 0');
  }
}
