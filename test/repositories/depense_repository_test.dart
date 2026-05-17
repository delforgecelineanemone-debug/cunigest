// Tests : DepenseRepository — agrégats financiers.
// Risque cible : un mauvais agrégat fausse le bilan financier et le
// calcul de marge. Bornes de date inclusives, comptes par catégorie
// corrects, total mensuel sur la bonne fenêtre glissante.

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/models/depense.dart';
import 'package:gestion_cunicole/repositories/depense_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

void main() {
  late Database db;
  late DepenseRepository repo;

  setUp(() async {
    db = await openTestDb();
    repo = DepenseRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> add({
    required String date,
    required String categorie,
    required double montant,
    int? lotId,
    int? lapinId,
  }) async {
    await repo.insert(Depense(
      dateDepense: date, categorie: categorie, montant: montant,
      lotId: lotId, lapinId: lapinId,
    ));
  }

  group('totalSurPeriode — bornes', () {
    test('bornes INCLUSIVES (from et to inclus)', () async {
      await add(date: '2026-05-01', categorie: 'aliment', montant: 100);
      await add(date: '2026-05-31', categorie: 'aliment', montant: 50);
      await add(date: '2026-04-30', categorie: 'aliment', montant: 999);
      await add(date: '2026-06-01', categorie: 'aliment', montant: 999);

      expect(
        await repo.totalSurPeriode('2026-05-01', '2026-05-31'),
        150.0,
      );
    });

    test('aucune dépense → 0.0 (pas null)', () async {
      expect(
        await repo.totalSurPeriode('2026-01-01', '2026-12-31'),
        0.0,
      );
    });
  });

  group('totalParCategorie', () {
    test('groupe par catégorie sur la période', () async {
      await add(date: '2026-05-01', categorie: 'aliment', montant: 100);
      await add(date: '2026-05-05', categorie: 'aliment', montant: 50);
      await add(date: '2026-05-10', categorie: 'soins', montant: 30);
      await add(date: '2026-06-10', categorie: 'aliment', montant: 999); // hors

      final m = await repo.totalParCategorie('2026-05-01', '2026-05-31');
      expect(m['aliment'], 150.0);
      expect(m['soins'], 30.0);
      expect(m.containsKey('autre'), isFalse);
    });
  });

  group('imputation lot/lapin', () {
    test('totalParLot ne compte que les dépenses du lot', () async {
      final lot1 = await db.insert('lots', {
        'code': 'LT1', 'date_creation': '2026-01-01', 'nombre_initial': 10,
      });
      final lot2 = await db.insert('lots', {
        'code': 'LT2', 'date_creation': '2026-01-01', 'nombre_initial': 10,
      });
      await add(date: '2026-05-01', categorie: 'aliment', montant: 100, lotId: lot1);
      await add(date: '2026-05-02', categorie: 'aliment', montant: 200, lotId: lot1);
      await add(date: '2026-05-03', categorie: 'aliment', montant: 999, lotId: lot2);
      await add(date: '2026-05-04', categorie: 'aliment', montant: 50); // pas de lot

      expect(await repo.totalParLot(lot1), 300.0);
      expect(await repo.totalParLot(9999), 0.0);
    });

    test('totalParLapin idem pour un reproducteur', () async {
      final lap7 = await db.insert('lapins', {
        'numero_bague': 'R7', 'sexe': 'femelle', 'date_creation': '2026-01-01',
      });
      final lap8 = await db.insert('lapins', {
        'numero_bague': 'R8', 'sexe': 'male', 'date_creation': '2026-01-01',
      });
      await add(
          date: '2026-05-01', categorie: 'reproducteur', montant: 80, lapinId: lap7);
      await add(
          date: '2026-05-10', categorie: 'soins', montant: 15, lapinId: lap7);
      await add(
          date: '2026-05-10', categorie: 'soins', montant: 999, lapinId: lap8);

      expect(await repo.totalParLapin(lap7), 95.0);
    });
  });

  group('getAll — filtres combinés', () {
    test('filtre par catégorie + plage de dates', () async {
      await add(date: '2026-05-01', categorie: 'aliment', montant: 10);
      await add(date: '2026-05-05', categorie: 'soins', montant: 20);
      await add(date: '2026-05-10', categorie: 'aliment', montant: 30);
      await add(date: '2026-06-01', categorie: 'aliment', montant: 99);

      final list = await repo.getAll(
        categorie: 'aliment',
        from: '2026-05-01',
        to: '2026-05-31',
      );
      expect(list.length, 2);
      expect(list.every((d) => d.categorie == 'aliment'), isTrue);
    });

    test('order desc par date_depense', () async {
      await add(date: '2026-05-01', categorie: 'aliment', montant: 10);
      await add(date: '2026-05-10', categorie: 'aliment', montant: 20);
      final list = await repo.getAll();
      expect(list.first.dateDepense, '2026-05-10');
    });
  });
}
