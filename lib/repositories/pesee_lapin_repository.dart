// ──────────────────────────────────────────────────────────────
// PeseeLapinRepository — pesées individuelles (V2.4 — Phase 4)
// ──────────────────────────────────────────────────────────────
// CRUD + helpers pour la croissance d'un lapin.
// ──────────────────────────────────────────────────────────────

import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/pesee_lapin.dart';

class PeseeLapinRepository {
  final Database _db;
  PeseeLapinRepository(this._db);

  Future<int> insert(PeseeLapin p) async {
    final m = p.toMap()..remove('id');
    final id = await _db.insert('pesees_lapin', m);
    // Met à jour le poids actuel du lapin (champ legacy `poids`).
    await _db.update(
      'lapins',
      {'poids': p.poids},
      where: 'id = ?',
      whereArgs: [p.lapinId],
    );
    return id;
  }

  Future<int> delete(int id) =>
      _db.delete('pesees_lapin', where: 'id = ?', whereArgs: [id]);

  Future<List<PeseeLapin>> getByLapin(int lapinId) async {
    final maps = await _db.query(
      'pesees_lapin',
      where: 'lapin_id = ?',
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
