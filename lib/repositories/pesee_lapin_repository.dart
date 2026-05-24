// ──────────────────────────────────────────────────────────────
// PeseeLapinRepository — pesées individuelles (V2.4 — Phase 4)
// ──────────────────────────────────────────────────────────────
// CRUD + helpers pour la croissance d'un lapin.
// ──────────────────────────────────────────────────────────────

import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/pesee_lapin.dart';
import '../services/data_bus.dart';
import 'sync_meta.dart';

class PeseeLapinRepository {
  final Database _db;
  final Future<void> Function(String, int, String, Map<String, dynamic>)?
      enqueueSyncIfEnabled;

  PeseeLapinRepository(this._db, {this.enqueueSyncIfEnabled});

  Future<int> insert(PeseeLapin p) async {
    final now = nowIso();
    final m = stampUpdated(p.toMap()..remove('id'));
    final id = await _db.insert('pesees_lapin', m);
    // Met à jour le poids actuel du lapin (champ legacy `poids`).
    final lapinRows = await _db.query('lapins',
        where: 'id = ?', whereArgs: [p.lapinId], limit: 1);
    await _db.update(
      'lapins',
      {'poids': p.poids, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [p.lapinId],
    );
    await enqueueSyncIfEnabled?.call(
        'pesees_lapin', id, 'insert', {...m, 'id': id});
    // Le lapin a aussi été modifié (poids) → enqueue son update.
    if (lapinRows.isNotEmpty) {
      final updated = Map<String, dynamic>.from(lapinRows.first);
      updated['poids'] = p.poids;
      updated['updated_at'] = now;
      await enqueueSyncIfEnabled?.call(
          'lapins', p.lapinId, 'update', updated);
    }
    DataBus.instance.notify(DataTopics.peseesLapin);
    DataBus.instance.notify(DataTopics.lapins);
    return id;
  }

  Future<int> delete(int id) async {
    final r = await softDelete(_db, 'pesees_lapin', id);
    await enqueueSyncIfEnabled?.call('pesees_lapin', id, 'delete', {'id': id, 'deleted_at': nowIso()});
    DataBus.instance.notify(DataTopics.peseesLapin);
    return r;
  }

  Future<List<PeseeLapin>> getByLapin(int lapinId) async {
    final maps = await _db.query(
      'pesees_lapin',
      where: 'lapin_id = ? AND $kNotDeletedWhere',
      whereArgs: [lapinId],
      orderBy: 'date_pesee ASC',
    );
    return maps.map(PeseeLapin.fromMap).toList();
  }

  /// GMQ (g/jour) entre la 1ère et la dernière pesée.
  /// Retourne null si moins de 2 pesées.
  Future<double?> calcGmq(int lapinId) async {
    final pesees = await getByLapin(lapinId);
    if (pesees.length < 2) return null;
    final first = pesees.first;
    final last = pesees.last;
    final d1 = DateTime.parse(first.datePesee);
    final d2 = DateTime.parse(last.datePesee);
    final jours = d2.difference(d1).inDays;
    if (jours <= 0) return null;
    final gainKg = last.poids - first.poids;
    return (gainKg * 1000) / jours;
  }
}
