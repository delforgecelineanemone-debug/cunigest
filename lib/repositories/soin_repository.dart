// ──────────────────────────────────────────────────────────────
// Repository : Soins — Suivi sanitaire et vaccinations (V3.0)
// ──────────────────────────────────────────────────────────────

import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/soin.dart';
import '../services/data_bus.dart';
import '../services/kpi_service.dart';
import 'repository_validators.dart';
import 'sync_meta.dart';

class SoinRepository {
  final Database db;
  final Future<void> Function(String, int, String, Map<String, dynamic>)? enqueueSyncIfEnabled;

  SoinRepository(this.db, {this.enqueueSyncIfEnabled});

  /// Enregistre un nouveau soin
  Future<int> insertSoin(Soin s) async {
    RepositoryValidators.assertValidSoin(s);
    final payload = stampUpdated(s.toMap());
    final id = await db.insert('soins', payload);
    await enqueueSyncIfEnabled?.call('soins', id, 'insert', {...payload, 'id': id});
    DataBus.instance.notify(DataTopics.soins);
    KpiService.instance.track(KpiEvent.soinEnregistre);
    return id;
  }

  /// Récupère tous les soins
  Future<List<Soin>> getAllSoins({int? limit, int? offset}) async {
    final maps = await db.query(
      'soins',
      where: kNotDeletedWhere,
      orderBy: 'date_soin DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => Soin.fromMap(m)).toList();
  }

  /// Récupère les soins d'un lapin spécifique
  Future<List<Soin>> getSoinsByLapin(int lapinId) async {
    final maps = await db.query('soins',
        where: 'lapin_id = ? AND $kNotDeletedWhere',
        whereArgs: [lapinId],
        orderBy: 'date_soin DESC');
    return maps.map((m) => Soin.fromMap(m)).toList();
  }

  /// Récupère les rappels de soins dans les X prochains jours
  Future<List<Soin>> getRappelsProchains(int jours) async {
    final limite = DateTime.now().add(Duration(days: jours)).toIso8601String().substring(0, 10);
    final maps = await db.query('soins',
        where: 'date_rappel IS NOT NULL AND date_rappel <= ? AND $kNotDeletedWhere',
        whereArgs: [limite],
        orderBy: 'date_rappel ASC');
    return maps.map((m) => Soin.fromMap(m)).toList();
  }

  /// Met à jour un soin
  Future<int> updateSoin(Soin s) async {
    RepositoryValidators.assertValidSoin(s);
    final payload = stampUpdated(s.toMap());
    final r = await db.update('soins', payload, where: 'id = ?', whereArgs: [s.id]);
    if (s.id != null) {
      await enqueueSyncIfEnabled?.call('soins', s.id!, 'update', payload);
    }
    DataBus.instance.notify(DataTopics.soins);
    return r;
  }

  /// Supprime un soin (soft-delete).
  Future<int> deleteSoin(int id) async {
    final r = await softDelete(db, 'soins', id);
    await enqueueSyncIfEnabled?.call('soins', id, 'delete', {'id': id, 'deleted_at': nowIso()});
    DataBus.instance.notify(DataTopics.soins);
    return r;
  }

  Future<int> count() async {
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM soins WHERE deleted_at IS NULL');
    return (r.first['c'] as int?) ?? 0;
  }

  /// Retourne le soin avec délai d'attente actif le plus tardif pour un lapin,
  /// ou null si aucun délai n'est en cours.
  Future<Soin?> getSoinDelaiAttenteActif(int lapinId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final maps = await db.rawQuery('''
      SELECT * FROM soins
      WHERE lapin_id = ?
        AND delai_attente_jours IS NOT NULL
        AND delai_attente_jours > 0
        AND deleted_at IS NULL
        AND date(date_soin, '+' || delai_attente_jours || ' days') > date(?)
      ORDER BY date(date_soin, '+' || delai_attente_jours || ' days') DESC
      LIMIT 1
    ''', [lapinId, today]);
    if (maps.isEmpty) return null;
    return Soin.fromMap(maps.first);
  }
}
