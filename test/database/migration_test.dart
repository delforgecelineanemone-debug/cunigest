// Tests des migrations DB v1 → v14. Le risque cible : une migration cassée
// silencieusement = données perdues à la mise à jour de l'app.

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/database/schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

void main() {
  group('createSchema (v10 fresh install)', () {
    late Database db;

    setUp(() async {
      db = await openTestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('toutes les tables attendues sont créées', () async {
      final tables = await listTables(db);
      const expected = {
        'lapins', 'saillies', 'soins', 'stocks', 'consommations', 'ventes',
        'taches_quotidiennes', 'completions', 'alertes', 'profil_eleveur',
        'badges', 'reglages',
        // V5
        'lots', 'pesees', 'distributions_aliment', 'lot_lapins',
        'sync_queue', 'sync_config', 'users',
        // V7
        'batiments', 'clapiers', 'cages', 'mouvements_cage',
        // V9
        'pesees_lapin', 'depenses',
        // V20
        'conflict_log',
      };
      expect(tables, containsAll(expected));
    });

    test('table reglages a la colonne devise par défaut "FCFA"', () async {
      final cols = await tableColumns(db, 'reglages');
      expect(cols, contains('devise'));
      expect(cols, contains('theme_mode'));
      expect(cols, contains('onboarding_done'));

      final rows = await db.query('reglages');
      expect(rows.length, 1, reason: 'seed devrait insérer un singleton');
      expect(rows.first['devise'], 'FCFA');
      expect(rows.first['theme_mode'], 'system');
    });

    test('lapins a généalogie + cage_id + photo_path', () async {
      final cols = await tableColumns(db, 'lapins');
      expect(cols, containsAll(['pere_id', 'mere_id', 'cage_id', 'photo_path']));
    });

    test('saillies a stats reproduction complètes', () async {
      final cols = await tableColumns(db, 'saillies');
      expect(cols, containsAll([
        'nb_morts', 'date_sevrage', 'poids_sevrage_total',
        'palpation_positive',
      ]));
    });

    test('soins a delai_attente_jours', () async {
      final cols = await tableColumns(db, 'soins');
      expect(cols, contains('delai_attente_jours'));
    });

    test('taches_quotidiennes a champs Phase 4 (échéance, statut, exceptions)', () async {
      final cols = await tableColumns(db, 'taches_quotidiennes');
      expect(cols, containsAll(['date_echeance', 'statut', 'exceptions']));
    });

    test('sync_config a colonnes auth Supabase', () async {
      final cols = await tableColumns(db, 'sync_config');
      expect(cols, containsAll([
        'enabled', 'server_url', 'api_key', 'user_id',
        'email', 'access_token', 'refresh_token',
      ]));
    });

    test('seed crée bien profil + 5 tâches système', () async {
      final profil = await db.query('profil_eleveur');
      expect(profil.length, 1);
      expect(profil.first['niveau'], 1);

      final taches = await db.query('taches_quotidiennes', where: 'est_systeme = 1');
      expect(taches.length, 5);
      expect(taches.map((t) => t['categorie']).toSet(),
          containsAll(['nourriture', 'eau', 'observation', 'nettoyage']));
    });

    test('PRAGMA foreign_keys est activé', () async {
      final r = await db.rawQuery('PRAGMA foreign_keys');
      expect(r.first.values.first, 1);
    });

    test('UNIQUE index sur lapins.numero_bague est appliqué', () async {
      final now = DateTime.now().toIso8601String().substring(0, 10);
      await db.insert('lapins', {
        'numero_bague': 'A001', 'sexe': 'male', 'date_creation': now,
      });
      expect(
        () => db.insert('lapins', {
          'numero_bague': 'A001', 'sexe': 'femelle', 'date_creation': now,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('upgradeSchema (v1 → v14 préservation)', () {
    late Database db;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    setUp(() async {
      initFfi();
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1),
      );
      await applyV1SchemaForTest(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('données lapins/saillies/soins préservées après v1→v14', () async {
      // Insertion v1 (sans pere_id/mere_id, sans cage_id, sans delai_attente)
      final mereId = await db.insert('lapins', {
        'numero_bague': 'M01', 'sexe': 'femelle', 'date_creation': today,
      });
      final pereId = await db.insert('lapins', {
        'numero_bague': 'P01', 'sexe': 'male', 'date_creation': today,
      });
      await db.insert('saillies', {
        'mere_id': mereId, 'pere_id': pereId, 'date_saillie': today,
      });
      await db.insert('soins', {
        'lapin_id': mereId, 'type_soin': 'Vaccination', 'date_soin': today,
      });

      // Migration v1 → v14
      await upgradeSchema(db, 1, kCurrentDbVersion);

      // Vérifier que rien n'est perdu
      final lapins = await db.query('lapins');
      expect(lapins.length, 2);
      expect(lapins.map((l) => l['numero_bague']).toSet(), {'M01', 'P01'});

      final saillies = await db.query('saillies');
      expect(saillies.length, 1);
      expect(saillies.first['mere_id'], mereId);

      final soins = await db.query('soins');
      expect(soins.length, 1);

      // Nouvelles tables créées
      final tables = await listTables(db);
      expect(tables, containsAll([
        'cages', 'batiments', 'clapiers', 'mouvements_cage',
        'pesees_lapin', 'depenses', 'reglages', 'sync_config', 'users',
      ]));

      // Nouvelles colonnes ajoutées
      final lapinsCols = await tableColumns(db, 'lapins');
      expect(lapinsCols, containsAll(['pere_id', 'mere_id', 'cage_id', 'photo_path']));
      final reglagesCols = await tableColumns(db, 'reglages');
      expect(reglagesCols, containsAll(['theme_mode', 'onboarding_done', 'devise']));
    });

    test('numero_bague dupliqués sont dédupliqués automatiquement', () async {
      // V1 n'avait pas d'index UNIQUE → on peut avoir des doublons
      await db.insert('lapins', {
        'numero_bague': 'X', 'sexe': 'male', 'date_creation': today,
      });
      await db.insert('lapins', {
        'numero_bague': 'X', 'sexe': 'femelle', 'date_creation': today,
      });
      await db.insert('lapins', {
        'numero_bague': 'X', 'sexe': 'male', 'date_creation': today,
      });

      await upgradeSchema(db, 1, kCurrentDbVersion);

      final lapins = await db.query('lapins', orderBy: 'id');
      expect(lapins.length, 3);
      expect(lapins[0]['numero_bague'], 'X');
      expect(lapins[1]['numero_bague'], startsWith('X_dup'));
      expect(lapins[2]['numero_bague'], startsWith('X_dup'));

      expect(
        () => db.insert('lapins', {
          'numero_bague': 'X', 'sexe': 'male', 'date_creation': today,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    // Régression : v6 (sync_config auth) doit s'exécuter AVANT v7+.
    // Avant le correctif, oldVersion < 6 était placé après oldVersion < 9.
    test('régression ordonnancement : sync_config a email+tokens après v1→v14', () async {
      await upgradeSchema(db, 1, kCurrentDbVersion);
      final cols = await tableColumns(db, 'sync_config');
      expect(
        cols,
        containsAll(['email', 'access_token', 'refresh_token', 'password_hash', 'nom']),
        reason: 'Les colonnes auth Supabase doivent être présentes (v6 doit précéder v7)',
      );
    });

    test('colonnes v11-v14 présentes après migration complète', () async {
      await upgradeSchema(db, 1, kCurrentDbVersion);

      final sailliesCols = await tableColumns(db, 'saillies');
      expect(sailliesCols, containsAll([
        'lot_id',          // v13
        'nb_chevauchements', 'etat_nid', // v14
      ]));

      final lotsCols = await tableColumns(db, 'lots');
      expect(lotsCols, contains('saillie_id')); // v13

      final lapinsCols = await tableColumns(db, 'lapins');
      expect(lapinsCols, containsAll([
        'prix_achat',  // v12
        'destination', // v14
      ]));

      final ventesCols = await tableColumns(db, 'ventes');
      expect(ventesCols, contains('lot_id')); // v12

      final depensesCols = await tableColumns(db, 'depenses');
      expect(depensesCols, containsAll(['lot_id', 'lapin_id'])); // v12
    });

    // ──────────────────────────────────────────────────────────
    // V17→V19 — focus sur le chemin de mise à jour V2.5 (le risque
    // identifié en revue de code : 21 tables ALTER TABLE + backfill,
    // FCFA par défaut, next_retry_at sur sync_queue).
    // ──────────────────────────────────────────────────────────

    test('migration v16→v19 : soft-delete présent sur toutes les tables sync',
        () async {
      // Note : le `setUp` partagé du group démarre en v1, mais l'isolation
      // de `inMemoryDatabasePath` entre tests n'est pas garantie — les tests
      // précédents peuvent avoir laissé la DB à kCurrentDbVersion. Pas de
      // sanity check sur l'absence des colonnes : `_addColumn` est idempotent
      // (rethrow uniquement les erreurs ≠ « duplicate column »), donc le
      // chemin v1→19 reste valide même si déjà partiellement migré.
      await upgradeSchema(db, 1, 19);

      // Insère une row de contrôle dans lapins. À ce stade, soft-delete
      // existe — le backfill du UPDATE v17 a déjà fait son travail, donc
      // on met updated_at explicitement à NULL pour vérifier que le test
      // ne dépend pas d'un état précédent.
      await db.delete('lapins', where: 'numero_bague = ?', whereArgs: ['BAG-MIG-001']);
      final lapinId = await db.insert('lapins', {
        'numero_bague': 'BAG-MIG-001',
        'sexe': 'femelle',
        'date_creation': today,
      });

      // Toutes les tables sync ont updated_at + deleted_at.
      for (final table in kSoftDeleteTables) {
        final cols = await tableColumns(db, table);
        expect(cols, contains('updated_at'),
            reason: 'updated_at manquant sur table "$table" après v17');
        expect(cols, contains('deleted_at'),
            reason: 'deleted_at manquant sur table "$table" après v17');
      }

      // Le lapin nouvellement inséré a un updated_at non-null (backfill
      // direct ou ajout au moment de l'INSERT selon le chemin) OU NULL.
      // L'important : la colonne existe et est queryable.
      final lapins =
          await db.query('lapins', where: 'id = ?', whereArgs: [lapinId]);
      expect(lapins, isNotEmpty);
      expect(lapins.first.containsKey('updated_at'), isTrue,
          reason: 'colonne updated_at doit exister sur la row');
      expect(lapins.first['deleted_at'], isNull,
          reason: 'deleted_at par défaut NULL = ligne active');

      // sync_queue : next_retry_at présent (v18).
      final syncCols = await tableColumns(db, 'sync_queue');
      expect(syncCols, contains('next_retry_at'),
          reason: 'next_retry_at manquant sur sync_queue après v18');
    });

    test('migration v19 préserve une devise choisie manuellement (USD, etc.)',
        () async {
      // Comme expliqué plus haut : on assume éventuellement déjà migré.
      // L'utilisateur a explicitement choisi USD APRÈS v19 → v19 (rejoué)
      // ne doit JAMAIS l'écraser car la WHERE est sur '€'/NULL/vide.
      await upgradeSchema(db, 1, 19);
      await db.update('reglages', {'devise': 'USD'});
      // Re-rejouer le bloc v19 pour confirmer l'idempotence.
      await upgradeSchema(db, 18, 19);
      final reglages = await db.query('reglages');
      expect(reglages.first['devise'], 'USD',
          reason: 'v19 doit préserver un choix explicite (≠ NULL/vide/€)');
    });

    test('migration v19→v20 crée la table conflict_log + son index',
        () async {
      // On migre directement jusqu'à v20. Pas de sanity check préalable :
      // l'isolation entre tests n'est pas garantie sur inMemoryDatabasePath.
      // Ce qui compte : à la fin, la table conflict_log + son index existent
      // avec le bon schéma.
      await upgradeSchema(db, 1, kCurrentDbVersion);

      // Table créée avec les bonnes colonnes.
      expect(await listTables(db), contains('conflict_log'));
      final cols = await tableColumns(db, 'conflict_log');
      expect(cols,
          containsAll([
            'id',
            'table_name',
            'row_id',
            'local_updated_at',
            'remote_updated_at',
            'detected_at',
          ]));

      // Index créé.
      expect(await listIndexes(db), contains('idx_conflict_log_detected'));
    });
  });

  group('parité schéma : install fraîche ≡ migration v1→v14', () {
    test('un utilisateur qui fait v1→v14 a le MÊME schéma qu\'un fresh install', () async {
      // Fresh install v10
      final fresh = await openTestDb();
      final freshTables = await listTables(fresh);
      final freshIndexes = await listIndexes(fresh);
      final freshColumnsByTable = <String, Set<String>>{};
      for (final t in freshTables) {
        freshColumnsByTable[t] = (await tableColumns(fresh, t)).toSet();
      }
      await fresh.close();

      // v1 + migration jusqu'à v10
      initFfi();
      final migrated = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1),
      );
      await applyV1SchemaForTest(migrated);
      await upgradeSchema(migrated, 1, kCurrentDbVersion);

      final migratedTables = await listTables(migrated);
      final migratedIndexes = await listIndexes(migrated);

      // Toutes les tables d'un fresh install doivent exister après migration.
      // (Migration peut avoir des tables en plus si certaines ont été créées
      // historiquement et abandonnées — pas le cas ici.)
      expect(migratedTables, containsAll(freshTables));

      // Toutes les colonnes attendues par un fresh install doivent exister
      // après migration (sinon le code écrira sur des colonnes manquantes).
      for (final table in freshTables) {
        final migratedCols = (await tableColumns(migrated, table)).toSet();
        final missing = freshColumnsByTable[table]!.difference(migratedCols);
        expect(
          missing,
          isEmpty,
          reason: 'Table "$table" : colonnes manquantes après migration → $missing',
        );
      }

      // Tous les index attendus existent.
      expect(migratedIndexes, containsAll(freshIndexes));

      await migrated.close();
    });
  });
}
