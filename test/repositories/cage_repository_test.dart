// Tests : CageRepository.deplacerLapin — opération transactionnelle.
// Risque cible : un échec en cours de déplacement laisse la base
// incohérente (lapin sans cage mais aucun mouvement enregistré, ou
// statut de cage faux). Doit être atomique.

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/models/batiment.dart';
import 'package:gestion_cunicole/models/cage.dart';
import 'package:gestion_cunicole/models/clapier.dart';
import 'package:gestion_cunicole/models/lapin.dart';
import 'package:gestion_cunicole/repositories/cage_repository.dart';
import 'package:gestion_cunicole/repositories/lapin_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

void main() {
  late Database db;
  late CageRepository cages;
  late LapinRepository lapins;

  late int cage1Id;
  late int cage2PleineId;

  setUp(() async {
    db = await openTestDb();
    cages = CageRepository(db);
    lapins = LapinRepository(db);

    // Bâtiment + clapier + 2 cages
    final batId = await cages.insertBatiment(Batiment(nom: 'Bat A'));
    final clapierId = await cages.insertClapier(
        Clapier(nom: 'Clapier 1', batimentId: batId));
    cage1Id = await cages.insertCage(
        Cage(numero: 'C1', clapierId: clapierId, capaciteMax: 2));
    cage2PleineId = await cages.insertCage(
        Cage(numero: 'C2', clapierId: clapierId, capaciteMax: 1));
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> addLapin(String bague, {int? cageId, String statut = 'actif'}) {
    final l = Lapin(numeroBague: bague, sexe: 'male', cageId: cageId);
    l.statut = statut;
    return lapins.insertLapin(l);
  }

  group('deplacerLapin — succès', () {
    test('lapin sans cage → cage1 : statut cage passe à occupee', () async {
      final lapinId = await addLapin('A');

      final mvtId = await cages.deplacerLapin(
          lapinId: lapinId, cageDestinationId: cage1Id, motif: 'Init');

      expect(mvtId, isPositive);

      // Lapin pointe sur cage1
      final l = await lapins.getLapinById(lapinId);
      expect(l!.cageId, cage1Id);

      // Cage1 status = occupee
      final c1 = await cages.getCageById(cage1Id);
      expect(c1!.statut, 'occupee');

      // Mouvement enregistré
      final hist = await cages.getHistoriqueLapin(lapinId);
      expect(hist.length, 1);
      expect(hist.first.cageOrigineId, isNull);
      expect(hist.first.cageDestinationId, cage1Id);
      expect(hist.first.motif, 'Init');
    });

    test('lapin de cage1 → cage2 : statut origine repasse à vide si dernier', () async {
      final lapinId = await addLapin('A', cageId: cage1Id);
      // Forcer cage1 à "occupee" (équivalent d'un seed)
      await db.update('cages', {'statut': 'occupee'},
          where: 'id = ?', whereArgs: [cage1Id]);

      await cages.deplacerLapin(
          lapinId: lapinId, cageDestinationId: cage2PleineId);

      // Cage1 redevient vide (plus aucun occupant)
      final c1 = await cages.getCageById(cage1Id);
      expect(c1!.statut, 'vide');

      // Cage2 devient occupee
      final c2 = await cages.getCageById(cage2PleineId);
      expect(c2!.statut, 'occupee');
    });

    test('sortie : lapin de cage1 vers null', () async {
      final lapinId = await addLapin('A', cageId: cage1Id);
      await db.update('cages', {'statut': 'occupee'},
          where: 'id = ?', whereArgs: [cage1Id]);

      await cages.deplacerLapin(
          lapinId: lapinId, cageDestinationId: null, motif: 'Sortie');

      final l = await lapins.getLapinById(lapinId);
      expect(l!.cageId, isNull);
      final c1 = await cages.getCageById(cage1Id);
      expect(c1!.statut, 'vide');
    });
  });

  group('deplacerLapin — erreurs', () {
    test('cage destination pleine → exception, AUCUN changement', () async {
      // Remplir cage2 (capaciteMax=1)
      final lapinDejaIn = await addLapin('Sit', cageId: cage2PleineId);

      final lapinId = await addLapin('A', cageId: cage1Id);

      await expectLater(
        cages.deplacerLapin(
            lapinId: lapinId, cageDestinationId: cage2PleineId),
        throwsA(isA<Exception>()),
      );

      // Aucun changement : lapin reste dans cage1, cage2 reste avec son
      // occupant initial, AUCUN mouvement enregistré.
      expect((await lapins.getLapinById(lapinId))!.cageId, cage1Id);
      expect((await lapins.getLapinById(lapinDejaIn))!.cageId, cage2PleineId);
      expect(await cages.getHistoriqueLapin(lapinId), isEmpty);
    });

    test('même cage → exception', () async {
      final lapinId = await addLapin('A', cageId: cage1Id);

      await expectLater(
        cages.deplacerLapin(
            lapinId: lapinId, cageDestinationId: cage1Id),
        throwsA(isA<Exception>()),
      );

      expect(await cages.getHistoriqueLapin(lapinId), isEmpty);
    });

    test('lapin inexistant → exception', () async {
      await expectLater(
        cages.deplacerLapin(
            lapinId: 9999, cageDestinationId: cage1Id),
        throwsA(isA<Exception>()),
      );
    });

    test('cage destination inexistante → exception', () async {
      final lapinId = await addLapin('A');
      await expectLater(
        cages.deplacerLapin(
            lapinId: lapinId, cageDestinationId: 9999),
        throwsA(isA<Exception>()),
      );
      // Aucune modification
      expect((await lapins.getLapinById(lapinId))!.cageId, isNull);
      expect(await cages.getHistoriqueLapin(lapinId), isEmpty);
    });
  });

  group('countOccupantsByCage', () {
    test('exclut les lapins morts/vendus', () async {
      await addLapin('A', cageId: cage1Id);
      await addLapin('B', cageId: cage1Id);
      await addLapin('C', cageId: cage1Id, statut: 'mort');
      await addLapin('D', cageId: cage1Id, statut: 'vendu');

      final counts = await cages.countOccupantsByCage();
      expect(counts[cage1Id], 2);
    });
  });
}
