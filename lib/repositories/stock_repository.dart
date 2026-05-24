// ──────────────────────────────────────────────────────────────
// Repository : Stocks — Alimentation et produits (V3.0)
// ──────────────────────────────────────────────────────────────

import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/stock.dart';
import '../services/data_bus.dart';
import 'sync_meta.dart';

class StockRepository {
  final Database db;
  final Future<void> Function(String, int, String, Map<String, dynamic>)? enqueueSyncIfEnabled;

  StockRepository(this.db, {this.enqueueSyncIfEnabled});

  Future<int> insertStock(Stock s) async {
    final payload = stampUpdated(s.toMap());
    final id = await db.insert('stocks', payload);
    await enqueueSyncIfEnabled?.call('stocks', id, 'insert', {...payload, 'id': id});
    DataBus.instance.notify(DataTopics.stocks);
    return id;
  }

  Future<List<Stock>> getAllStocks() async {
    final maps = await db.query('stocks',
        where: kNotDeletedWhere, orderBy: 'type_aliment, produit');
    return maps.map((m) => Stock.fromMap(m)).toList();
  }

  Future<List<Stock>> getStocksCritiques() async {
    final maps = await db.query('stocks',
        where: 'quantite <= quantite_min AND $kNotDeletedWhere',
        orderBy: 'quantite ASC');
    return maps.map((m) => Stock.fromMap(m)).toList();
  }

  Future<int> updateStock(Stock s) async {
    final payload = stampUpdated(s.toMap());
    final r = await db.update('stocks', payload, where: 'id = ?', whereArgs: [s.id]);
    if (s.id != null) {
      await enqueueSyncIfEnabled?.call('stocks', s.id!, 'update', payload);
    }
    DataBus.instance.notify(DataTopics.stocks);
    return r;
  }

  Future<int> deleteStock(int id) async {
    final r = await softDelete(db, 'stocks', id);
    await enqueueSyncIfEnabled?.call('stocks', id, 'delete', {'id': id, 'deleted_at': nowIso()});
    DataBus.instance.notify(DataTopics.stocks);
    return r;
  }

  /// Enregistre une consommation de stock et réduit la quantité.
  /// Atomique grâce à la transaction.
  Future<int> consommerStock(int stockId, double quantite, String date) async {
    final now = nowIso();
    final r = await db.transaction((txn) async {
      await txn.insert('consommations', {
        'stock_id': stockId,
        'quantite': quantite,
        'date_consommation': date,
        'updated_at': now,
      });
      return txn.rawUpdate(
          'UPDATE stocks SET quantite = quantite - ?, updated_at = ? WHERE id = ?',
          [quantite, now, stockId]);
    });
    final rows = await db.query('stocks', where: 'id = ?', whereArgs: [stockId], limit: 1);
    if (rows.isNotEmpty) {
      await enqueueSyncIfEnabled?.call('stocks', stockId, 'update', rows.first);
    }
    DataBus.instance.notify(DataTopics.stocks);
    return r;
  }
}
