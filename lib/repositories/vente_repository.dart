// ──────────────────────────────────────────────────────────────
// Repository : Ventes — Gestion des ventes de lapins (V3.0)
// ──────────────────────────────────────────────────────────────

import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/vente.dart';
import '../services/data_bus.dart';
import '../services/kpi_service.dart';
import 'repository_validators.dart';
import 'sync_meta.dart';

class VenteRepository {
  final Database db;
  final Future<void> Function(String, int, String, Map<String, dynamic>)? enqueueSyncIfEnabled;

  VenteRepository(this.db, {this.enqueueSyncIfEnabled});

  Future<int> insertVente(Vente v) async {
    RepositoryValidators.assertValidVente(v);
    final payload = stampUpdated(v.toMap());
    final id = await db.transaction((txn) async {
      final i = await txn.insert('ventes', payload);
      if (v.lapinId != null) {
        final now = nowIso();
        await txn.update('lapins', {'statut': 'vendu', 'updated_at': now},
            where: 'id = ?', whereArgs: [v.lapinId]);
      }
      return i;
    });
    await enqueueSyncIfEnabled?.call('ventes', id, 'insert', {...payload, 'id': id});
    DataBus.instance.notify(DataTopics.ventes);
    // Le statut du lapin a pu passer à "vendu" — notifier la table lapins.
    if (v.lapinId != null) DataBus.instance.notify(DataTopics.lapins);
    KpiService.instance.track(KpiEvent.venteEnregistree);
    return id;
  }

  Future<List<Vente>> getAllVentes({int? limit, int? offset}) async {
    final maps = await db.query('ventes',
        where: kNotDeletedWhere,
        orderBy: 'date_vente DESC', limit: limit, offset: offset);
    return maps.map((m) => Vente.fromMap(m)).toList();
  }

  /// Ventes liées à un lot (via `lot_id`).
  Future<List<Vente>> getByLot(int lotId) async {
    final maps = await db.query('ventes',
        where: 'lot_id = ? AND $kNotDeletedWhere',
        whereArgs: [lotId], orderBy: 'date_vente DESC');
    return maps.map(Vente.fromMap).toList();
  }

  /// Ventes liées à un lapin individuel (via `lapin_id`).
  Future<List<Vente>> getByLapin(int lapinId) async {
    final maps = await db.query('ventes',
        where: 'lapin_id = ? AND $kNotDeletedWhere',
        whereArgs: [lapinId], orderBy: 'date_vente DESC');
    return maps.map(Vente.fromMap).toList();
  }

  /// Total des ventes d'un lot (somme des prix).
  Future<double> totalParLot(int lotId) async {
    final r = await db.rawQuery(
      'SELECT COALESCE(SUM(prix_vente), 0) AS total FROM ventes WHERE lot_id = ? AND deleted_at IS NULL',
      [lotId],
    );
    return ((r.first['total'] as num?) ?? 0).toDouble();
  }

  /// Total des ventes d'un lapin individuel.
  Future<double> totalParLapin(int lapinId) async {
    final r = await db.rawQuery(
      'SELECT COALESCE(SUM(prix_vente), 0) AS total FROM ventes WHERE lapin_id = ? AND deleted_at IS NULL',
      [lapinId],
    );
    return ((r.first['total'] as num?) ?? 0).toDouble();
  }

  Future<int> updateVente(Vente v) async {
    RepositoryValidators.assertValidVente(v);
    final payload = stampUpdated(v.toMap());
    final r = await db.update('ventes', payload, where: 'id = ?', whereArgs: [v.id]);
    if (v.id != null) {
      await enqueueSyncIfEnabled?.call('ventes', v.id!, 'update', payload);
    }
    DataBus.instance.notify(DataTopics.ventes);
    return r;
  }

  Future<int> deleteVente(int id) async {
    final r = await softDelete(db, 'ventes', id);
    await enqueueSyncIfEnabled?.call('ventes', id, 'delete', {'id': id, 'deleted_at': nowIso()});
    DataBus.instance.notify(DataTopics.ventes);
    return r;
  }

  Future<int> count() async {
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM ventes WHERE deleted_at IS NULL');
    return (r.first['c'] as int?) ?? 0;
  }

  /// Top clients (acheteurs) sur une période, classés par CA décroissant.
  /// Ignore les ventes sans nom d'acheteur (anonymes).
  /// Retourne une liste de Map { 'nom': String, 'total': double, 'nb_ventes': int }
  Future<List<Map<String, dynamic>>> getTopClients({
    required String from,
    required String to,
    int limit = 5,
  }) async {
    final r = await db.rawQuery(
      'SELECT acheteur AS nom, '
      'COALESCE(SUM(prix_vente), 0) AS total, '
      'COUNT(*) AS nb_ventes '
      'FROM ventes '
      "WHERE acheteur IS NOT NULL AND TRIM(acheteur) <> '' "
      'AND date_vente BETWEEN ? AND ? '
      'GROUP BY acheteur '
      'ORDER BY total DESC '
      'LIMIT ?',
      [from, to, limit],
    );
    return r
        .map((row) => {
              'nom': row['nom'] as String,
              'total': ((row['total'] as num?) ?? 0).toDouble(),
              'nb_ventes': (row['nb_ventes'] as int?) ?? 0,
            })
        .toList();
  }

  Future<Map<String, dynamic>> getStatistiquesVentes() async {
    final totalResult = await db.rawQuery('SELECT COUNT(*) as count, COALESCE(SUM(prix_vente), 0) as total FROM ventes');
    final moisActuel = DateTime.now().toIso8601String().substring(0, 7);
    final moisResult = await db.rawQuery(
      'SELECT COUNT(*) as count, COALESCE(SUM(prix_vente), 0) as total FROM ventes WHERE date_vente LIKE ?',
      ['$moisActuel%'],
    );
    return {
      'nombre_total': totalResult.first['count'] as int,
      'chiffre_affaires_total': (totalResult.first['total'] as num).toDouble(),
      'nombre_mois': moisResult.first['count'] as int,
      'chiffre_affaires_mois': (moisResult.first['total'] as num).toDouble(),
    };
  }
}
