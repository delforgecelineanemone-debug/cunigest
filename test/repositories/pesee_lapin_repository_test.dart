// Tests : PeseeLapinRepository — synchro pesée ↔ lapin.poids et calcul GMQ.
// Risque cible : la pesée doit aussi mettre à jour le champ legacy
// `lapins.poids` (utilisé partout dans l'UI), et le GMQ doit gérer les
// cas dégénérés (< 2 pesées, même date) sans diviser par zéro.

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/models/lapin.dart';
import 'package:gestion_cunicole/models/pesee_lapin.dart';
import 'package:gestion_cunicole/repositories/lapin_repository.dart';
import 'package:gestion_cunicole/repositories/pesee_lapin_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

void main() {
  late Database db;
  late PeseeLapinRepository repo;
  late LapinRepository lapins;
  late int lapinId;

  setUp(() async {
    db = await openTestDb();
    repo = PeseeLapinRepository(db);
    lapins = LapinRepository(db);
    lapinId = await lapins.insertLapin(
      Lapin(numeroBague: 'L1', sexe: 'male', poids: 1.0),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('insert', () {
    test('met à jour le poids du lapin (champ legacy)', () async {
      await repo.insert(
        PeseeLapin(lapinId: lapinId, datePesee: '2026-05-01', poids: 2.5),
      );
      final l = await lapins.getLapinById(lapinId);
      expect(l!.poids, 2.5);
    });

    test('dernière pesée écrase la précédente sur lapins.poids', () async {
      await repo.insert(
        PeseeLapin(lapinId: lapinId, datePesee: '2026-05-01', poids: 2.0),
      );
      await repo.insert(
        PeseeLapin(lapinId: lapinId, datePesee: '2026-05-10', poids: 2.8),
      );
      final l = await lapins.getLapinById(lapinId);
      expect(l!.poids, 2.8);
    });
  });

  group('calcGmq', () {
    test('moins de 2 pesées → null', () async {
      expect(await repo.calcGmq(lapinId), isNull);
      await repo.insert(
        PeseeLapin(lapinId: lapinId, datePesee: '2026-05-01', poids: 2.0),
      );
      expect(await repo.calcGmq(lapinId), isNull);
    });

    test('2 pesées espacées de 10j (+ 500g) → 50 g/j', () async {
      await repo.insert(
        PeseeLapin(lapinId: lapinId, datePesee: '2026-05-01', poids: 1.0),
      );
      await repo.insert(
        PeseeLapin(lapinId: lapinId, datePesee: '2026-05-11', poids: 1.5),
      );
      expect(await repo.calcGmq(lapinId), closeTo(50, 0.01));
    });

    test('2 pesées le même jour → null (pas de division par zéro)', () async {
      await repo.insert(
        PeseeLapin(lapinId: lapinId, datePesee: '2026-05-01', poids: 1.0),
      );
      await repo.insert(
        PeseeLapin(lapinId: lapinId, datePesee: '2026-05-01', poids: 1.2),
      );
      expect(await repo.calcGmq(lapinId), isNull);
    });

    test('perte de poids → GMQ négatif', () async {
      await repo.insert(
        PeseeLapin(lapinId: lapinId, datePesee: '2026-05-01', poids: 2.0),
      );
      await repo.insert(
        PeseeLapin(lapinId: lapinId, datePesee: '2026-05-11', poids: 1.5),
      );
      final gmq = await repo.calcGmq(lapinId);
      expect(gmq, lessThan(0));
    });
  });

  group('cascade suppression lapin', () {
    test('supprimer le lapin → ses pesées disparaissent (FK CASCADE)', () async {
      await repo.insert(
        PeseeLapin(lapinId: lapinId, datePesee: '2026-05-01', poids: 2.0),
      );
      await db.delete('lapins', where: 'id = ?', whereArgs: [lapinId]);
      expect(await repo.getByLapin(lapinId), isEmpty);
    });
  });
}
