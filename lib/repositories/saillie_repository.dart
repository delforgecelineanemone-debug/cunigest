// ──────────────────────────────────────────────────────────────
// Repository : Saillies — Reproduction (V3.0)
// ──────────────────────────────────────────────────────────────

import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/saillie.dart';
import '../services/data_bus.dart';
import '../services/kpi_service.dart';
import 'repository_validators.dart';
import 'sync_meta.dart';

class SaillieRepository {
  final Database db;
  final Future<void> Function(String, int, String, Map<String, dynamic>)? enqueueSyncIfEnabled;

  SaillieRepository(this.db, {this.enqueueSyncIfEnabled});

  /// Enregistre une nouvelle saillie
  Future<int> insertSaillie(Saillie s) async {
    RepositoryValidators.assertValidSaillie(s);
    final payload = stampUpdated(s.toMap());
    final id = await db.insert('saillies', payload);
    await enqueueSyncIfEnabled?.call('saillies', id, 'insert', {...payload, 'id': id});
    DataBus.instance.notify(DataTopics.saillies);
    KpiService.instance.track(KpiEvent.saillieEnregistree);
    return id;
  }

  /// Récupère toutes les saillies, de la plus récente à la plus ancienne
  Future<List<Saillie>> getAllSaillies({int? limit, int? offset}) async {
    final maps = await db.query(
      'saillies',
      where: kNotDeletedWhere,
      orderBy: 'date_saillie DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => Saillie.fromMap(m)).toList();
  }

  /// Récupère les saillies d'une mère spécifique
  Future<List<Saillie>> getSailliesByMere(int mereId) async {
    final maps = await db.query('saillies',
        where: 'mere_id = ? AND $kNotDeletedWhere',
        whereArgs: [mereId],
        orderBy: 'date_saillie DESC');
    return maps.map((m) => Saillie.fromMap(m)).toList();
  }

  /// Récupère les saillies d'un père spécifique
  Future<List<Saillie>> getSailliesByPere(int pereId) async {
    final maps = await db.query('saillies',
        where: 'pere_id = ? AND $kNotDeletedWhere',
        whereArgs: [pereId],
        orderBy: 'date_saillie DESC');
    return maps.map((m) => Saillie.fromMap(m)).toList();
  }

  /// Récupère les saillies en attente de mise bas
  Future<List<Saillie>> getSailliesEnAttente() async {
    final maps = await db.query('saillies',
        where: 'statut = ? AND $kNotDeletedWhere',
        whereArgs: ['en_attente']);
    return maps.map((m) => Saillie.fromMap(m)).toList();
  }

  /// Met à jour une saillie
  Future<int> updateSaillie(Saillie s) async {
    RepositoryValidators.assertValidSaillie(s);
    final payload = stampUpdated(s.toMap());
    final r = await db.update('saillies', payload, where: 'id = ?', whereArgs: [s.id]);
    if (s.id != null) {
      await enqueueSyncIfEnabled?.call('saillies', s.id!, 'update', payload);
    }
    DataBus.instance.notify(DataTopics.saillies);
    return r;
  }

  /// Supprime une saillie (soft-delete : `deleted_at` rempli).
  Future<int> deleteSaillie(int id) async {
    final r = await softDelete(db, 'saillies', id);
    await enqueueSyncIfEnabled?.call('saillies', id, 'delete', {'id': id, 'deleted_at': nowIso()});
    DataBus.instance.notify(DataTopics.saillies);
    return r;
  }

  Future<int> countTerminees() async {
    final r = await db.rawQuery(
      "SELECT COUNT(*) as c FROM saillies WHERE statut IN ('mise_bas', 'sevrage', 'termine') AND deleted_at IS NULL",
    );
    return (r.first['c'] as int?) ?? 0;
  }

  /// Statistiques globales de reproduction
  Future<Map<String, dynamic>> getStatistiquesReproduction() async {
    final totalRow = await db.rawQuery('SELECT COUNT(*) as c FROM saillies WHERE deleted_at IS NULL');
    final positivesRow = await db.rawQuery(
        "SELECT COUNT(*) as c FROM saillies WHERE (palpation_positive = 1 OR statut IN ('mise_bas','sevrage','termine')) AND deleted_at IS NULL");
    final echecsRow = await db.rawQuery("SELECT COUNT(*) as c FROM saillies WHERE statut = 'echec' AND deleted_at IS NULL");

    final prolificiteRow = await db.rawQuery(
        'SELECT AVG(nb_vivants) as moy, SUM(nb_vivants) as tot, SUM(nb_nes) as totNes, SUM(nb_morts) as totMorts FROM saillies WHERE nb_vivants IS NOT NULL AND deleted_at IS NULL');

    final sevreRow = await db.rawQuery(
        'SELECT SUM(nb_vivants) as totVivants, SUM(nb_sevres) as totSevres FROM saillies WHERE nb_sevres IS NOT NULL AND nb_vivants IS NOT NULL AND deleted_at IS NULL');

    final total = (totalRow.first['c'] as int?) ?? 0;
    final positives = (positivesRow.first['c'] as int?) ?? 0;
    final echecs = (echecsRow.first['c'] as int?) ?? 0;
    final palpees = positives + echecs;
    final tauxFertilite = palpees > 0 ? (positives / palpees) * 100 : null;

    final prolificiteMoy = prolificiteRow.first['moy'] as num?;
    final totalNesVivants = (prolificiteRow.first['tot'] as int?) ?? 0;
    final totalNes = (prolificiteRow.first['totNes'] as int?) ?? 0;
    final totalMorts = (prolificiteRow.first['totMorts'] as int?) ?? 0;

    final totVivantsSevre = (sevreRow.first['totVivants'] as int?) ?? 0;
    final totSevres = (sevreRow.first['totSevres'] as int?) ?? 0;
    final tauxMortalitePreSevrage = totVivantsSevre > 0
        ? ((totVivantsSevre - totSevres) / totVivantsSevre) * 100
        : null;

    return {
      'nombre_saillies': total,
      'nombre_positives': positives,
      'nombre_echecs': echecs,
      'taux_fertilite_pct': tauxFertilite,
      'prolificite_moyenne': prolificiteMoy?.toDouble(),
      'total_nes_vivants': totalNesVivants,
      'total_nes': totalNes,
      'total_morts_naissance': totalMorts,
      'total_sevres': totSevres,
      'taux_mortalite_pre_sevrage_pct': tauxMortalitePreSevrage,
    };
  }
}
