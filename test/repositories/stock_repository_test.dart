// Tests : StockRepository — consommerStock (transaction) et stocks critiques.
// Risque cible : un crash en plein milieu de consommerStock peut soit
// décrémenter le stock sans tracer la consommation, soit l'inverse —
// les deux désynchronisent comptabilité et inventaire. La requête
// stocks critiques doit aussi attraper les seuils égaux (≤).

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/models/stock.dart';
import 'package:gestion_cunicole/repositories/stock_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

void main() {
  late Database db;
  late StockRepository repo;

  setUp(() async {
    db = await openTestDb();
    repo = StockRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> ajouterStock(double qte, {double min = 0}) {
    return repo.insertStock(Stock(
      produit: 'Granulés',
      typeAliment: 'Granulés',
      quantite: qte,
      unite: 'kg',
      quantiteMin: min,
    ));
  }

  group('consommerStock — atomicité et calcul', () {
    test('crée une consommation ET décrémente le stock', () async {
      final id = await ajouterStock(100);
      await repo.consommerStock(id, 25, '2026-05-01');

      final stocks = await repo.getAllStocks();
      expect(stocks.first.quantite, 75.0);

      final conso = await db.query('consommations');
      expect(conso.length, 1);
      expect(conso.first['quantite'], 25.0);
      expect(conso.first['stock_id'], id);
    });

    test('consommation supérieure au stock → quantité négative permise',
        () async {
      // Comportement actuel : pas de contrainte CHECK. Si ça change,
      // ce test signalera la rupture (et il faudra alors valider la
      // protection métier en amont).
      final id = await ajouterStock(10);
      await repo.consommerStock(id, 15, '2026-05-01');
      final stocks = await repo.getAllStocks();
      expect(stocks.first.quantite, -5.0);
    });

    test('consommer un stock_id inexistant → exception ET rollback', () async {
      // FK consommations.stock_id → stocks.id : insertion impossible.
      // La transaction doit échouer entièrement (pas de conso fantôme).
      await expectLater(
        repo.consommerStock(9999, 5, '2026-05-01'),
        throwsA(isA<DatabaseException>()),
      );
      expect(await db.query('consommations'), isEmpty);
    });
  });

  group('getStocksCritiques', () {
    test('seuil égal → inclus (≤ et non <)', () async {
      await ajouterStock(10, min: 10); // exactement au seuil
      await ajouterStock(50, min: 10); // largement au-dessus

      final crit = await repo.getStocksCritiques();
      expect(crit.length, 1);
      expect(crit.first.quantite, 10);
    });

    test('triés par quantité croissante', () async {
      await ajouterStock(8, min: 20);
      await ajouterStock(2, min: 20);
      await ajouterStock(15, min: 20);

      final crit = await repo.getStocksCritiques();
      expect(crit.map((s) => s.quantite).toList(), [2.0, 8.0, 15.0]);
    });

    test('quantité strictement au-dessus → exclu', () async {
      await ajouterStock(11, min: 10);
      expect(await repo.getStocksCritiques(), isEmpty);
    });
  });

  group('soft-delete', () {
    test('supprimer un stock le retire de getAllStocks() sans purge physique',
        () async {
      final id = await ajouterStock(50);
      await repo.consommerStock(id, 5, '2026-05-01');
      expect((await db.query('consommations')).length, 1);

      await repo.deleteStock(id);

      // Soft-delete : le stock n'apparaît plus dans la liste métier...
      final visibles = await repo.getAllStocks();
      expect(visibles.where((s) => s.id == id), isEmpty);

      // ...mais la row existe toujours en base avec deleted_at rempli
      // (préservation jusqu'à confirmation du push cloud).
      final raw = await db.query('stocks', where: 'id = ?', whereArgs: [id]);
      expect(raw.length, 1);
      expect(raw.first['deleted_at'], isNotNull);

      // Les consommations historiques sont conservées (faits passés).
      expect((await db.query('consommations')).length, 1);
    });
  });
}
