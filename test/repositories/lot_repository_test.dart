// Tests : LotRepository — calculs GMQ / IC et cycle de vie du lot.
// Risque cible : un GMQ ou un IC erroné fausse complètement le
// pilotage de l'engraissement (l'éleveur décide quand vendre).
// Les formules doivent gérer 0 pesée, 0 distribution, jours=0
// et l'unicité du code lot.

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/models/lot.dart';
import 'package:gestion_cunicole/repositories/lot_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

void main() {
  late Database db;
  late LotRepository repo;

  setUp(() async {
    db = await openTestDb();
    repo = LotRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  String _isoDayOffset(int days) => DateTime.now()
      .subtract(Duration(days: days))
      .toIso8601String()
      .substring(0, 10);

  group('UNIQUE code', () {
    test('insertion d\'un lot avec un code déjà pris → exception', () async {
      await repo.insertLot(Lot(
          code: 'LT1', dateCreation: '2026-01-01', nombreInitial: 30));
      await expectLater(
        repo.insertLot(Lot(
            code: 'LT1', dateCreation: '2026-01-02', nombreInitial: 40)),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('getStats — calculs GMQ et IC', () {
    test('lot inexistant → stats vides', () async {
      final s = await repo.getStats(9999);
      expect(s.nombreActuel, 0);
      expect(s.alimentTotalKg, 0);
      expect(s.gmq, isNull);
      expect(s.ic, isNull);
    });

    test('lot sans pesée ni distribution → nombreActuel = initial, GMQ/IC null',
        () async {
      final id = await repo.insertLot(Lot(
          code: 'L1',
          dateCreation: _isoDayOffset(10),
          nombreInitial: 30,
          poidsInitial: 18.0));
      final s = await repo.getStats(id);
      expect(s.nombreActuel, 30);
      expect(s.gmq, isNull);
      expect(s.ic, isNull);
      expect(s.alimentTotalKg, 0);
      expect(s.joursElevage, greaterThanOrEqualTo(10));
    });

    test('GMQ correct sur 10 jours, 30 lapereaux, +9 kg', () async {
      // initial 18kg / 30 lapereaux ; après 10j : 27kg
      // gain = 9kg = 9000g ; 9000 / (10 * 30) = 30 g/j/lapereau
      final id = await repo.insertLot(Lot(
          code: 'L2',
          dateCreation: _isoDayOffset(10),
          nombreInitial: 30,
          poidsInitial: 18.0));
      await repo.insertPesee(Pesee(
          lotId: id,
          datePesee: _isoDayOffset(0),
          poidsTotal: 27.0,
          nombre: 30));

      final s = await repo.getStats(id);
      expect(s.gmq, closeTo(30, 0.1));
    });

    test('IC = aliment / poids vif produit', () async {
      // gain 9kg, aliment 27kg → IC = 27/9 = 3.0
      final id = await repo.insertLot(Lot(
          code: 'L3',
          dateCreation: _isoDayOffset(10),
          nombreInitial: 30,
          poidsInitial: 18.0));
      await repo.insertPesee(Pesee(
          lotId: id,
          datePesee: _isoDayOffset(0),
          poidsTotal: 27.0,
          nombre: 30));
      await repo.insertDistribution(DistributionAliment(
          lotId: id,
          dateDistribution: _isoDayOffset(5),
          quantiteKg: 27.0));

      final s = await repo.getStats(id);
      expect(s.ic, closeTo(3.0, 0.01));
      expect(s.alimentTotalKg, 27.0);
    });

    test('aliment distribué mais poids stagnant → IC null (pas d\'infinité)',
        () async {
      final id = await repo.insertLot(Lot(
          code: 'L4',
          dateCreation: _isoDayOffset(5),
          nombreInitial: 20,
          poidsInitial: 12.0));
      await repo.insertPesee(Pesee(
          lotId: id,
          datePesee: _isoDayOffset(0),
          poidsTotal: 12.0,
          nombre: 20));
      await repo.insertDistribution(DistributionAliment(
          lotId: id,
          dateDistribution: _isoDayOffset(2),
          quantiteKg: 10.0));

      final s = await repo.getStats(id);
      expect(s.ic, isNull, reason: 'éviter la division par zéro');
    });

    test('lot terminé → jours elevage figé à dateFin (pas "maintenant")',
        () async {
      final id = await repo.insertLot(Lot(
          code: 'L5',
          dateCreation: '2026-01-01',
          nombreInitial: 20,
          poidsInitial: 12.0));
      await repo.terminer(id, '2026-02-01');
      final s = await repo.getStats(id);
      expect(s.joursElevage, 31);
    });
  });

  group('lapins du lot', () {
    test('ajouterLapin deux fois → ignoré (PRIMARY KEY composite)', () async {
      final id = await repo.insertLot(Lot(
          code: 'L6', dateCreation: '2026-01-01', nombreInitial: 10));
      // Insère un lapin minimal directement pour avoir un FK valide.
      final lapinId = await db.insert('lapins', {
        'numero_bague': 'X1',
        'sexe': 'male',
        'date_creation': '2026-01-01',
      });

      await repo.ajouterLapin(id, lapinId, '2026-01-02');
      await repo.ajouterLapin(id, lapinId, '2026-01-03'); // ignoré

      final ids = await repo.getLapinIdsDuLot(id);
      expect(ids, [lapinId]);
    });

    test('retirerLapin → exclu de getLapinIdsDuLot par défaut', () async {
      final id = await repo.insertLot(Lot(
          code: 'L7', dateCreation: '2026-01-01', nombreInitial: 10));
      final lapinId = await db.insert('lapins', {
        'numero_bague': 'X2',
        'sexe': 'male',
        'date_creation': '2026-01-01',
      });

      await repo.ajouterLapin(id, lapinId, '2026-01-02');
      await repo.retirerLapin(id, lapinId, '2026-01-20', 'vente');

      expect(await repo.getLapinIdsDuLot(id), isEmpty);
      expect(await repo.getLapinIdsDuLot(id, seulementPresents: false),
          [lapinId]);
    });
  });
}
