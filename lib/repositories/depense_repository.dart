// ──────────────────────────────────────────────────────────────
// DepenseRepository — module Finances (V2.4 — Phase 4)
// ──────────────────────────────────────────────────────────────
// CRUD + agrégats par mois et par catégorie pour le suivi
// des dépenses et le calcul du coût de production.
// ──────────────────────────────────────────────────────────────

import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/depense.dart';
import '../services/data_bus.dart';
import 'repository_validators.dart';
import 'sync_meta.dart';

class DepenseRepository {
  final Database _db;
  final Future<void> Function(String, int, String, Map<String, dynamic>)?
      enqueueSyncIfEnabled;

  DepenseRepository(this._db, {this.enqueueSyncIfEnabled});

  Future<int> insert(Depense d) async {
    RepositoryValidators.assertValidDepense(d);
    final m = stampUpdated(d.toMap()..remove('id'));
    final id = await _db.insert('depenses', m);
    await enqueueSyncIfEnabled?.call(
        'depenses', id, 'insert', {...m, 'id': id});
    DataBus.instance.notify(DataTopics.depenses);
    return id;
  }

  Future<int> update(Depense d) async {
    RepositoryValidators.assertValidDepense(d);
    final payload = stampUpdated(d.toMap());
    final r = await _db.update('depenses', payload,
        where: 'id = ?', whereArgs: [d.id]);
    if (d.id != null) {
      await enqueueSyncIfEnabled?.call(
          'depenses', d.id!, 'update', payload);
    }
    DataBus.instance.notify(DataTopics.depenses);
    return r;
  }

  Future<int> delete(int id) async {
    final r = await softDelete(_db, 'depenses', id);
    await enqueueSyncIfEnabled?.call('depenses', id, 'delete', {'id': id, 'deleted_at': nowIso()});
    DataBus.instance.notify(DataTopics.depenses);
    return r;
  }

  Future<List<Depense>> getAll({
    String? categorie,
    String? from,
    String? to,
    int? limit,
    int? offset,
  }) async {
    final wheres = <String>['deleted_at IS NULL'];
    final args = <Object?>[];
    if (categorie != null) {
      wheres.add('categorie = ?');
      args.add(categorie);
    }
    if (from != null) {
      wheres.add('date_depense >= ?');
      args.add(from);
    }
    if (to != null) {
      wheres.add('date_depense <= ?');
      args.add(to);
    }
    final maps = await _db.query(
      'depenses',
      where: wheres.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date_depense DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map(Depense.fromMap).toList();
  }

  /// Total dépensé sur une période.
  Future<double> totalSurPeriode(String from, String to) async {
    final r = await _db.rawQuery(
      'SELECT COALESCE(SUM(montant), 0) AS total FROM depenses '
      'WHERE date_depense BETWEEN ? AND ? AND deleted_at IS NULL',
      [from, to],
    );
    return ((r.first['total'] as num?) ?? 0).toDouble();
  }

  /// Agrégat par catégorie sur une période. Retourne {categorie: total}.
  Future<Map<String, double>> totalParCategorie(String from, String to) async {
    final r = await _db.rawQuery(
      'SELECT categorie, SUM(montant) AS total FROM depenses '
      'WHERE date_depense BETWEEN ? AND ? AND deleted_at IS NULL GROUP BY categorie',
      [from, to],
    );
    return {
      for (final row in r)
        row['categorie'] as String: ((row['total'] as num?) ?? 0).toDouble(),
    };
  }

  /// Liste des dépenses imputées à un lot (avec total).
  Future<List<Depense>> getByLot(int lotId) async {
    final maps = await _db.query('depenses',
        where: 'lot_id = ? AND $kNotDeletedWhere',
        whereArgs: [lotId],
        orderBy: 'date_depense DESC');
    return maps.map(Depense.fromMap).toList();
  }

  /// Liste des dépenses imputées à un lapin (reproducteur).
  Future<List<Depense>> getByLapin(int lapinId) async {
    final maps = await _db.query('depenses',
        where: 'lapin_id = ? AND $kNotDeletedWhere',
        whereArgs: [lapinId],
        orderBy: 'date_depense DESC');
    return maps.map(Depense.fromMap).toList();
  }

  /// Total des dépenses imputées à un lot.
  Future<double> totalParLot(int lotId) async {
    final r = await _db.rawQuery(
      'SELECT COALESCE(SUM(montant), 0) AS total FROM depenses WHERE lot_id = ? AND deleted_at IS NULL',
      [lotId],
    );
    return ((r.first['total'] as num?) ?? 0).toDouble();
  }

  /// Total des dépenses imputées à un lapin.
  Future<double> totalParLapin(int lapinId) async {
    final r = await _db.rawQuery(
      'SELECT COALESCE(SUM(montant), 0) AS total FROM depenses WHERE lapin_id = ? AND deleted_at IS NULL',
      [lapinId],
    );
    return ((r.first['total'] as num?) ?? 0).toDouble();
  }

  /// Total mensuel sur N derniers mois. Clé "AAAA-MM" → total.
  Future<Map<String, double>> totalMensuel(int nbMois) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month - nbMois + 1, 1)
        .toIso8601String()
        .substring(0, 10);
    final r = await _db.rawQuery(
      'SELECT substr(date_depense, 1, 7) AS mois, SUM(montant) AS total '
      'FROM depenses WHERE date_depense >= ? AND deleted_at IS NULL GROUP BY mois ORDER BY mois ASC',
      [from],
    );
    return {
      for (final row in r)
        row['mois'] as String: ((row['total'] as num?) ?? 0).toDouble(),
    };
  }
}
