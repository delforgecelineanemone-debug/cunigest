// ──────────────────────────────────────────────────────────────
// Repository : Saillies — Reproduction (V3.0)
// ──────────────────────────────────────────────────────────────

import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/saillie.dart';

class SaillieRepository {
  final Database db;
  final Future<void> Function(String, int, String, Map<String, dynamic>)? enqueueSyncIfEnabled;

  SaillieRepository(this.db, {this.enqueueSyncIfEnabled});

  /// Enregistre une nouvelle saillie
  Future<int> insertSaillie(Saillie s) async {
    final id = await db.insert('saillies', s.toMap());
    await enqueueSyncIfEnabled?.call('saillies', id, 'insert', {...s.toMap(), 'id': id});
    return id;
  }

  /// Récupère toutes les saillies, de la plus récente à la plus ancienne
  Future<List<Saillie>> getAllSaillies({int? limit, int? offset}) async {
    final maps = await db.query(
      'saillies',
      orderBy: 'date_saillie DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => Saillie.fromMap(m)).toList();
  }

  /// Récupère les saillies d'une mère spécifique
  Future<List<Saillie>> getSailliesByMere(int mereId) async {
    final maps = await db.query('saillies', where: 'mere_id = ?', whereArgs: [mereId], orderBy: 'date_saillie DESC');
    return maps.map((m) => Saillie.fromMap(m)).toList();
  }

  /// Récupère les saillies d'un père spécifique
  Future<List<Saillie>> getSailliesByPere(int pereId) async {
    final maps = await db.query('saillies', where: 'pere_id = ?', whereArgs: [pereId], orderBy: 'date_saillie DESC');
    return maps.map((m) => Saillie.fromMap(m)).toList();
  }

  /// Récupère les saillies en attente de mise bas
  Future<List<Saillie>> getSailliesEnAttente() async {
    final maps = await db.query('saillies', where: 'statut = ?', whereArgs: ['en_attente']);
    return maps.map((m) => Saillie.fromMap(m)).toList();
  }

  /// Met à jour une saillie
  Future<int> updateSaillie(Saillie s) async {
    final r = await db.update('saillies', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
    if (s.id != null) {
      await enqueueSyncIfEnabled?.call('saillies', s.id!, 'update', s.toMap());
    }
    return r;
  }

  /// Supprime une saillie
  Future<int> deleteSaillie(int id) async {
    final r = await db.delete('saillies', where: 'id = ?', whereArgs: [id]);
    await enqueueSyncIfEnabled?.call('saillies', id, 'delete', {'id': id});
    return r;
  }

  Future<int> countTerminees() async {
    final r = await db.rawQuery(
      "SELECT COUNT(*) as c FROM saillies WHERE statut IN ('mise_bas', 'sevrage', 'termine')",
    );
    return (r.first['c'] as int?) ?? 0;
  }

  /// Statistiques globales de reproduction
  Future<Map<String, dynamic>> getStatistiquesReproduction() async {
    final totalRow = await db.rawQuery('SELECT COUNT(*) as c FROM saillies');
    final positivesRow = await db.rawQuery(
        "SELECT COUNT(*) as c FROM saillies WHERE palpation_positive = 1 OR statut IN ('mise_bas','sevrage','termine')");
    final echecsRow = await db.rawQuery("SELECT COUNT(*) as c FROM saillies WHERE statut = 'echec'");

    final prolificiteRow = await db.rawQuery(
        'SELECT AVG(nb_vivants) as moy, SUM(nb_vivants) as tot, SUM(nb_nes) as totNes, SUM(nb_morts) as totMorts FROM saillies WHERE nb_vivants IS NOT NULL');

    final sevreRow = await db.rawQuery(
        'SELECT SUM(nb_vivants) as totVivants, SUM(nb_sevres) as totSevres FROM saillies WHERE nb_sevres IS NOT NULL AND nb_vivants IS NOT NULL');

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
