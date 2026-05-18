// Tests : SoinRepository — rappels et délai d'attente médicaments.
// Risque cible CRITIQUE : un lapin vendu pendant son délai d'attente
// = résidus médicamenteux dans la viande. getSoinDelaiAttenteActif doit
// retourner le délai le plus tardif et ignorer les délais expirés.

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/models/soin.dart';
import 'package:gestion_cunicole/repositories/soin_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

void main() {
  late Database db;
  late SoinRepository repo;
  late int lapinId;

  setUp(() async {
    db = await openTestDb();
    repo = SoinRepository(db);
    lapinId = await db.insert('lapins', {
      'numero_bague': 'L1', 'sexe': 'male', 'date_creation': '2026-01-01',
    });
  });

  tearDown(() async {
    await db.close();
  });

  String isoOffset(int days) => DateTime.now()
      .subtract(Duration(days: days))
      .toIso8601String()
      .substring(0, 10);

  String isoFuture(int days) => DateTime.now()
      .add(Duration(days: days))
      .toIso8601String()
      .substring(0, 10);

  group('getRappelsProchains', () {
    test('inclut les rappels passés non traités', () async {
      // Un rappel d'il y a 5 jours doit toujours apparaître (l'éleveur
      // ne l'a pas fait à temps mais il faut quand même le voir).
      await repo.insertSoin(Soin(
        lapinId: lapinId, typeSoin: 'Vaccination VHD',
        dateSoin: isoOffset(40), dateRappel: isoOffset(5),
      ));
      final r = await repo.getRappelsProchains(7);
      expect(r.length, 1);
    });

    test('exclut les rappels au-delà de la fenêtre', () async {
      await repo.insertSoin(Soin(
        lapinId: lapinId, typeSoin: 'Vaccination Myxomatose',
        dateSoin: isoOffset(1), dateRappel: isoFuture(30),
      ));
      final r = await repo.getRappelsProchains(7);
      expect(r, isEmpty);
    });

    test('exclut les soins sans date_rappel', () async {
      await repo.insertSoin(Soin(
        lapinId: lapinId, typeSoin: 'Pesée', dateSoin: isoOffset(0),
      ));
      final r = await repo.getRappelsProchains(30);
      expect(r, isEmpty);
    });

    test('triés par date_rappel ASC', () async {
      await repo.insertSoin(Soin(
          lapinId: lapinId, typeSoin: 'A', dateSoin: isoOffset(10),
          dateRappel: isoFuture(5)));
      await repo.insertSoin(Soin(
          lapinId: lapinId, typeSoin: 'B', dateSoin: isoOffset(10),
          dateRappel: isoFuture(2)));
      final r = await repo.getRappelsProchains(7);
      expect(r.map((s) => s.typeSoin).toList(), ['B', 'A']);
    });
  });

  group('getSoinDelaiAttenteActif', () {
    test('aucun soin → null', () async {
      expect(await repo.getSoinDelaiAttenteActif(lapinId), isNull);
    });

    test('délai en cours (date_soin + délai > today) → retourne le soin',
        () async {
      // Antibiotique il y a 5 jours, délai 28j → encore 23 jours
      await repo.insertSoin(Soin(
        lapinId: lapinId, typeSoin: 'Antibiotique',
        dateSoin: isoOffset(5), delaiAttenteJours: 28,
      ));
      final s = await repo.getSoinDelaiAttenteActif(lapinId);
      expect(s, isNotNull);
      expect(s!.typeSoin, 'Antibiotique');
    });

    test('délai expiré → null', () async {
      // Antibiotique il y a 30 jours, délai 28 → expiré depuis 2j
      await repo.insertSoin(Soin(
        lapinId: lapinId, typeSoin: 'Antibiotique',
        dateSoin: isoOffset(30), delaiAttenteJours: 28,
      ));
      expect(await repo.getSoinDelaiAttenteActif(lapinId), isNull);
    });

    test('plusieurs soins → retourne celui qui finit le plus tard', () async {
      // 2 soins actifs simultanément, on doit avoir le dernier à expirer
      await repo.insertSoin(Soin(
        lapinId: lapinId, typeSoin: 'Antiparasitaire',
        dateSoin: isoOffset(2), delaiAttenteJours: 14, // expire J+12
      ));
      await repo.insertSoin(Soin(
        lapinId: lapinId, typeSoin: 'Antibiotique',
        dateSoin: isoOffset(1), delaiAttenteJours: 28, // expire J+27
      ));
      final s = await repo.getSoinDelaiAttenteActif(lapinId);
      expect(s!.typeSoin, 'Antibiotique');
    });

    test('soin sans délai d\'attente → ignoré', () async {
      await repo.insertSoin(Soin(
        lapinId: lapinId, typeSoin: 'Pesée',
        dateSoin: isoOffset(1), delaiAttenteJours: null,
      ));
      expect(await repo.getSoinDelaiAttenteActif(lapinId), isNull);
    });
  });

  group('cascade lapin', () {
    test('supprimer le lapin → cascade sur ses soins', () async {
      await repo.insertSoin(Soin(
        lapinId: lapinId, typeSoin: 'Pesée', dateSoin: '2026-01-01',
      ));
      await db.delete('lapins', where: 'id = ?', whereArgs: [lapinId]);
      expect(await repo.count(), 0);
    });
  });
}
