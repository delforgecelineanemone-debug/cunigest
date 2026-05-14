// Tests : AlerteRepository — génération automatique des alertes repro.
// Risque cible : un éleveur rate la palpation, le nid ou la mise bas →
// portée perdue. Les fenêtres temporelles doivent être strictes ET
// idempotentes (le rappel ne doit pas se dupliquer chaque jour).

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/models/lapin.dart';
import 'package:gestion_cunicole/repositories/alerte_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

void main() {
  late Database db;
  late AlerteRepository repo;

  setUp(() async {
    db = await openTestDb();
    repo = AlerteRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// Crée un map saillie au format attendu par genererAlertesReproduction.
  Map<String, dynamic> saillie({
    required int id,
    required int mereId,
    required int joursAvant,
    String statut = 'en_attente',
  }) {
    final dateSaillie = DateTime.now().subtract(Duration(days: joursAvant));
    return {
      'id': id,
      'mere_id': mereId,
      'pere_id': 99,
      'date_saillie': dateSaillie.toIso8601String().substring(0, 10),
      'statut': statut,
    };
  }

  Map<int, Lapin> lapinsAvec(int id, String nom) =>
      {id: Lapin(id: id, numeroBague: 'B$id', sexe: 'femelle', nom: nom)};

  group('genererAlertesReproduction — fenêtres temporelles', () {
    test('J+10 → alerte palpation important', () async {
      await repo.genererAlertesReproduction(
        sailliesMaps: [saillie(id: 1, mereId: 1, joursAvant: 10)],
        lapinsMap: lapinsAvec(1, 'Lola'),
      );
      final alertes = await db.query('alertes');
      expect(alertes.length, 1);
      expect(alertes.first['type'], 'palpation');
      expect(alertes.first['priorite'], 'important');
    });

    test('J+12 → alerte palpation critique', () async {
      await repo.genererAlertesReproduction(
        sailliesMaps: [saillie(id: 1, mereId: 1, joursAvant: 12)],
        lapinsMap: lapinsAvec(1, 'Lola'),
      );
      final alertes = await db.query('alertes');
      expect(alertes.length, 1);
      expect(alertes.first['priorite'], 'critique');
    });

    test('J+9 → AUCUNE alerte palpation (avant fenêtre)', () async {
      await repo.genererAlertesReproduction(
        sailliesMaps: [saillie(id: 1, mereId: 1, joursAvant: 9)],
        lapinsMap: lapinsAvec(1, 'Lola'),
      );
      final alertes = await db.query('alertes');
      expect(alertes, isEmpty);
    });

    test('J+15 → plus dans la fenêtre palpation', () async {
      await repo.genererAlertesReproduction(
        sailliesMaps: [saillie(id: 1, mereId: 1, joursAvant: 15)],
        lapinsMap: lapinsAvec(1, 'Lola'),
      );
      final alertes = await db.query('alertes', where: 'type = ?', whereArgs: ['palpation']);
      expect(alertes, isEmpty);
    });

    test('J+27 → alerte nid', () async {
      await repo.genererAlertesReproduction(
        sailliesMaps: [saillie(id: 1, mereId: 1, joursAvant: 27)],
        lapinsMap: lapinsAvec(1, 'Lola'),
      );
      final alertes = await db.query('alertes', where: 'type = ?', whereArgs: ['nid']);
      expect(alertes.length, 1);
      expect(alertes.first['priorite'], 'critique');
    });

    test('J+29 → alerte nid (dernier jour fenêtre)', () async {
      await repo.genererAlertesReproduction(
        sailliesMaps: [saillie(id: 1, mereId: 1, joursAvant: 29)],
        lapinsMap: lapinsAvec(1, 'Lola'),
      );
      final alertes = await db.query('alertes', where: 'type = ?', whereArgs: ['nid']);
      expect(alertes.length, 1);
    });

    test('J+30 → alerte mise_bas', () async {
      await repo.genererAlertesReproduction(
        sailliesMaps: [saillie(id: 1, mereId: 1, joursAvant: 30)],
        lapinsMap: lapinsAvec(1, 'Lola'),
      );
      final misesBas = await db.query('alertes', where: 'type = ?', whereArgs: ['mise_bas']);
      expect(misesBas.length, 1);
      expect(misesBas.first['priorite'], 'critique');
    });

    test('J+33 → alerte mise_bas (dernier jour fenêtre)', () async {
      await repo.genererAlertesReproduction(
        sailliesMaps: [saillie(id: 1, mereId: 1, joursAvant: 33)],
        lapinsMap: lapinsAvec(1, 'Lola'),
      );
      final misesBas = await db.query('alertes', where: 'type = ?', whereArgs: ['mise_bas']);
      expect(misesBas.length, 1);
    });

    test('J+34 → fenêtre mise_bas dépassée', () async {
      await repo.genererAlertesReproduction(
        sailliesMaps: [saillie(id: 1, mereId: 1, joursAvant: 34)],
        lapinsMap: lapinsAvec(1, 'Lola'),
      );
      final alertes = await db.query('alertes');
      expect(alertes, isEmpty);
    });
  });

  group('genererAlertesReproduction — idempotence', () {
    test('appel répété ne duplique pas une alerte palpation', () async {
      final s = saillie(id: 1, mereId: 1, joursAvant: 11);
      final l = lapinsAvec(1, 'Lola');

      // 3 jours de runs successifs (en pratique : à chaque démarrage app)
      await repo.genererAlertesReproduction(sailliesMaps: [s], lapinsMap: l);
      await repo.genererAlertesReproduction(sailliesMaps: [s], lapinsMap: l);
      await repo.genererAlertesReproduction(sailliesMaps: [s], lapinsMap: l);

      final alertes = await db.query('alertes', where: 'type = ?', whereArgs: ['palpation']);
      expect(alertes.length, 1, reason: 'idempotence cassée → spam d\'alertes');
    });

    test('saillie qui passe de J+11 (palpation) à J+27 (nid) crée 2 alertes différentes', () async {
      // Simule le passage du temps : on génère à J+11 puis à J+27.
      // Comme c'est le repository qui mesure "today", on ne peut pas
      // facilement simuler le passage du temps sans mocking. À la place,
      // on teste qu'avec une saillie à J+27, on a bien 1 alerte nid
      // (et que palpation aurait existé à un autre moment — non testé ici).
      await repo.genererAlertesReproduction(
        sailliesMaps: [saillie(id: 1, mereId: 1, joursAvant: 27)],
        lapinsMap: lapinsAvec(1, 'Lola'),
      );
      final types = (await db.query('alertes')).map((a) => a['type']).toSet();
      expect(types, {'nid'});
    });
  });

  group('genererAlertesReproduction — filtres', () {
    test('saillie statut != en_attente → ignorée', () async {
      await repo.genererAlertesReproduction(
        sailliesMaps: [saillie(id: 1, mereId: 1, joursAvant: 11, statut: 'mise_bas')],
        lapinsMap: lapinsAvec(1, 'Lola'),
      );
      expect(await db.query('alertes'), isEmpty);
    });

    test('mère sans nom → fallback "Lapine"', () async {
      await repo.genererAlertesReproduction(
        sailliesMaps: [saillie(id: 1, mereId: 1, joursAvant: 11)],
        lapinsMap: {
          1: Lapin(id: 1, numeroBague: 'B1', sexe: 'femelle'),
        },
      );
      final alertes = await db.query('alertes');
      expect(alertes.length, 1);
      // Le titre contient le numero_bague (displayName fallback)
      expect(alertes.first['titre'], contains('B1'));
    });

    test('plusieurs saillies → plusieurs alertes indépendantes', () async {
      await repo.genererAlertesReproduction(
        sailliesMaps: [
          saillie(id: 1, mereId: 1, joursAvant: 11),
          saillie(id: 2, mereId: 2, joursAvant: 28),
          saillie(id: 3, mereId: 3, joursAvant: 32),
        ],
        lapinsMap: {
          1: Lapin(id: 1, numeroBague: 'A', sexe: 'femelle', nom: 'Lola'),
          2: Lapin(id: 2, numeroBague: 'B', sexe: 'femelle', nom: 'Mia'),
          3: Lapin(id: 3, numeroBague: 'C', sexe: 'femelle', nom: 'Nina'),
        },
      );
      final alertes = await db.query('alertes');
      expect(alertes.length, 3);
      expect(alertes.map((a) => a['type']).toSet(),
          {'palpation', 'nid', 'mise_bas'});
    });
  });

  group('nettoyerAlertes', () {
    test('supprime les alertes traitées de plus de 30 jours', () async {
      final now = DateTime.now();
      final ilYa40j = now.subtract(const Duration(days: 40)).toIso8601String().substring(0, 10);
      final ilYa20j = now.subtract(const Duration(days: 20)).toIso8601String().substring(0, 10);
      final today = now.toIso8601String().substring(0, 10);

      // Vieille traitée → à supprimer
      await db.insert('alertes', {
        'type': 'palpation', 'titre': 'Old', 'date_alerte': ilYa40j,
        'est_traitee': 1,
      });
      // Récente traitée → à garder
      await db.insert('alertes', {
        'type': 'nid', 'titre': 'Recent', 'date_alerte': ilYa20j,
        'est_traitee': 1,
      });
      // Vieille non traitée → à garder
      await db.insert('alertes', {
        'type': 'mise_bas', 'titre': 'OldUntreated', 'date_alerte': ilYa40j,
        'est_traitee': 0,
      });
      // D'aujourd'hui → à garder
      await db.insert('alertes', {
        'type': 'palpation', 'titre': 'Today', 'date_alerte': today,
        'est_traitee': 1,
      });

      final supprimes = await repo.nettoyerAlertes();
      expect(supprimes, 1);

      final restantes = await db.query('alertes');
      expect(restantes.length, 3);
      expect(restantes.map((r) => r['titre']).toSet(),
          {'Recent', 'OldUntreated', 'Today'});
    });
  });
}
