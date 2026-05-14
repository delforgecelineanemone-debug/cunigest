// Helper de test : ouvre une base SQLite en mémoire (sans SQLCipher)
// pour valider migrations / repositories sans toucher au stockage natif.

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gestion_cunicole/database/schema.dart';

/// Initialise le moteur sqflite_ffi pour les tests Flutter desktop.
/// Idempotent : peut être appelé plusieurs fois.
void initFfi() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// Ouvre une base de données en mémoire à la version `version` du schéma
/// CuniGest. Si `seed` est vrai, exécute aussi les inserts par défaut
/// (profil, réglages, tâches système).
///
/// Le moteur ffi est initialisé automatiquement.
Future<Database> openTestDb({int version = kCurrentDbVersion, bool seed = true}) async {
  initFfi();
  return await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: version,
      onConfigure: onConfigureSchema,
      onCreate: (db, v) async {
        await createSchema(db, v);
        if (seed) await seedInitialData(db);
      },
      onUpgrade: upgradeSchema,
    ),
  );
}

/// Ouvre une base à une `oldVersion` puis simule une mise à jour vers
/// `newVersion`. Utile pour tester les chemins `_upgradeDB`.
///
/// La création initiale utilise un schéma minimal v1 (avant les évolutions).
/// Pour ne pas dupliquer la définition v1 ici, on ouvre directement à
/// `oldVersion` via le mécanisme interne de sqflite, qui appellera onCreate
/// (avec notre schéma actuel) puis nous ré-ouvrons à newVersion → onUpgrade.
///
/// ATTENTION : ce helper part de la version courante du schéma comme base
/// "vide", ce qui n'est pas un test parfait des migrations historiques.
/// Pour ces dernières, voir `applyV1SchemaForTest` ci-dessous.
Future<Database> openTestDbAtVersion(int oldVersion) async {
  initFfi();
  return await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: oldVersion,
      onConfigure: onConfigureSchema,
      onCreate: (db, v) async {
        await createSchema(db, v);
        await seedInitialData(db);
      },
    ),
  );
}

/// Schéma v1 minimal (pré-historique du projet) — uniquement les 5 tables
/// d'origine, telles qu'elles existaient avant `_upgradeDB`. Permet de
/// simuler une vraie installation legacy puis de jouer toutes les migrations.
Future<void> applyV1SchemaForTest(Database db) async {
  await db.execute('PRAGMA foreign_keys = ON');
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
      notes TEXT,
      date_creation TEXT NOT NULL
    )
  ''');
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
      nb_sevres INTEGER,
      statut TEXT DEFAULT 'en_attente',
      notes TEXT,
      FOREIGN KEY (mere_id) REFERENCES lapins(id),
      FOREIGN KEY (pere_id) REFERENCES lapins(id)
    )
  ''');
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
      notes TEXT,
      FOREIGN KEY (lapin_id) REFERENCES lapins(id) ON DELETE CASCADE
    )
  ''');
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
  await db.execute('PRAGMA user_version = 1');
}

/// Liste les tables présentes dans une base.
Future<Set<String>> listTables(Database db) async {
  final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_metadata'");
  return rows.map((r) => r['name'] as String).toSet();
}

/// Liste les colonnes d'une table.
Future<List<String>> tableColumns(Database db, String table) async {
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  return rows.map((r) => r['name'] as String).toList();
}

/// Liste les index présents.
Future<Set<String>> listIndexes(Database db) async {
  final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%'");
  return rows.map((r) => r['name'] as String).toSet();
}
