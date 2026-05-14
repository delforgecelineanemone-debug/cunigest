// ──────────────────────────────────────────────────────────────
// Repository : Stocks — Alimentation et produits (V3.0)
// ──────────────────────────────────────────────────────────────

import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/stock.dart';

class StockRepository {
  final Database db;
  final Future<void> Function(String, int, String, Map<String, dynamic>)? enqueueSyncIfEnabled;

  StockRepository(this.db, {this.enqueueSyncIfEnabled});

  Future<int> insertStock(Stock s) async {
    final id = await db.insert('stocks', s.toMap());
    await enqueueSyncIfEnabled?.call('stocks', id, 'insert', {...s.toMap(), 'id': id});
    return id;
  }

  Future<List<Stock>> getAllStocks() async {
    final maps = await db.query('stocks', orderBy: 'type_aliment, produit');
    return maps.map((m) => Stock.fromMap(m)).toList();
  }

  Future<List<Stock>> getStocksCritiques() async {
    final maps = await db.query('stocks',
        where: 'quantite <= quantite_min',
        orderBy: 'quantite ASC');
    return maps.map((m) => Stock.fromMap(m)).toList();
  }

  Future<int> updateStock(Stock s) async {
    final r = await db.update('stocks', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
    if (s.id != null) {
      await enqueueSyncIfEnabled?.call('stocks', s.id!, 'update', s.toMap());
    }
    return r;
  }

  Future<int> deleteStock(int id) async {
    final r = await db.delete('stocks', where: 'id = ?', whereArgs: [id]);
    await enqueueSyncIfEnabled?.call('stocks', id, 'delete', {'id': id});
    return r;
  }

  /// Enregistre une consommation de stock et réduit la quantité.
  /// Atomique grâce à la transaction.
  Future<int> consommerStock(int stockId, double quantite, String date) async {
    final r = await db.transaction((txn) async {
      await txn.insert('consommations', {
        'stock_id': stockId,
        'quantite': quantite,
        'date_consommation': date,
      });
      return txn.rawUpdate(
          'UPDATE stocks SET quantite = quantite - ? WHERE id = ?',
          [quantite, stockId]);
    });
    final rows = await db.query('stocks', where: 'id = ?', whereArgs: [stockId], limit: 1);
    if (rows.isNotEmpty) {
      await enqueueSyncIfEnabled?.call('stocks', stockId, 'update', rows.first);
    }
    return r;
  }
}
