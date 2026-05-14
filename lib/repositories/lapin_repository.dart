// ──────────────────────────────────────────────────────────────
// Repository : Lapins — CRUD + généalogie + consanguinité (V3.0)
// ──────────────────────────────────────────────────────────────
// Extrait de db_helper.dart pour respecter le Single Responsibility
// Principle. Reçoit un objet Database injecté par DBHelper.
// ──────────────────────────────────────────────────────────────

import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/lapin.dart';

class LapinRepository {
  final Database db;
  final Future<void> Function(String, int, String, Map<String, dynamic>)? enqueueSyncIfEnabled;

  LapinRepository(this.db, {this.enqueueSyncIfEnabled});

  /// Ajoute un nouveau lapin dans la base.
  /// Lance une `DatabaseException` en cas de doublon de numéro de bague.
  Future<int> insertLapin(Lapin lapin) async {
    final id = await db.insert('lapins', lapin.toMap());
    await enqueueSyncIfEnabled?.call('lapins', id, 'insert', {...lapin.toMap(), 'id': id});
    return id;
  }

  /// Récupère tous les lapins, triés du plus récent au plus ancien
  Future<List<Lapin>> getAllLapins({int? limit, int? offset}) async {
    final maps = await db.query(
      'lapins',
      orderBy: 'date_creation DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => Lapin.fromMap(m)).toList();
  }

  Future<Map<int, Lapin>> getLapinsByIds(Iterable<int> ids) async {
    final uniqueIds = ids.toSet().toList();
    if (uniqueIds.isEmpty) return {};
    final placeholders = List.filled(uniqueIds.length, '?').join(',');
    final maps = await db.query(
      'lapins',
      where: 'id IN ($placeholders)',
      whereArgs: uniqueIds,
    );
    return {
      for (final l in maps.map((m) => Lapin.fromMap(m)))
        if (l.id != null) l.id!: l,
    };
  }

  /// Récupère les lapins par statut (actif, vendu, mort, sevrage)
  Future<List<Lapin>> getLapinsByStatut(String statut) async {
    final maps = await db.query('lapins', where: 'statut = ?', whereArgs: [statut]);
    return maps.map((m) => Lapin.fromMap(m)).toList();
  }

  /// Récupère les lapins actifs par sexe
  Future<List<Lapin>> getLapinsBySexe(String sexe) async {
    final maps = await db.query('lapins', where: 'sexe = ? AND statut = ?', whereArgs: [sexe, 'actif']);
    return maps.map((m) => Lapin.fromMap(m)).toList();
  }

  /// Récupère un lapin par son ID
  Future<Lapin?> getLapinById(int id) async {
    final maps = await db.query('lapins', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Lapin.fromMap(maps.first);
  }

  /// Met à jour les informations d'un lapin
  Future<int> updateLapin(Lapin lapin) async {
    final r = await db.update('lapins', lapin.toMap(), where: 'id = ?', whereArgs: [lapin.id]);
    if (lapin.id != null) {
      await enqueueSyncIfEnabled?.call('lapins', lapin.id!, 'update', lapin.toMap());
    }
    return r;
  }

  /// Supprime un lapin de la base.
  /// Les soins liés seront supprimés en cascade ; les ventes et liens
  /// généalogiques (pere_id/mere_id) seront mis à NULL.
  Future<int> deleteLapin(int id) async {
    final r = await db.delete('lapins', where: 'id = ?', whereArgs: [id]);
    await enqueueSyncIfEnabled?.call('lapins', id, 'delete', {'id': id});
    return r;
  }

  /// Calcule les statistiques globales des lapins
  Future<Map<String, int>> getStatistiquesLapins() async {
    final all = await db.rawQuery('SELECT statut, COUNT(*) as count FROM lapins GROUP BY statut');
    final males = await db.rawQuery("SELECT COUNT(*) as count FROM lapins WHERE sexe='male' AND statut='actif'");
    final femelles = await db.rawQuery("SELECT COUNT(*) as count FROM lapins WHERE sexe='femelle' AND statut='actif'");
    return {
      'total': all.fold(0, (sum, r) => sum + (r['count'] as int)),
      'actifs': all.where((r) => r['statut'] == 'actif').fold(0, (s, r) => s + (r['count'] as int)),
      'males': males.first['count'] as int,
      'femelles': femelles.first['count'] as int,
    };
  }

  /// Naissances groupées par mois sur les `nbMois` derniers mois (mois courant inclus).
  /// Retourne un Map ordonné { "AAAA-MM": count }, mois sans naissance inclus à 0.
  Future<Map<String, int>> naissancesParMois(int nbMois) async {
    final now = DateTime.now();
    final premierMois = DateTime(now.year, now.month - nbMois + 1, 1);
    final fromStr = premierMois.toIso8601String().substring(0, 10);

    final r = await db.rawQuery(
      'SELECT substr(date_naissance, 1, 7) AS mois, COUNT(*) AS c '
      'FROM lapins WHERE date_naissance IS NOT NULL AND date_naissance >= ? '
      'GROUP BY mois',
      [fromStr],
    );
    final raw = {
      for (final row in r)
        row['mois'] as String: (row['c'] as int?) ?? 0,
    };

    // Remplir les mois sans naissance avec 0, ordre chronologique.
    final result = <String, int>{};
    for (int i = 0; i < nbMois; i++) {
      final m = DateTime(premierMois.year, premierMois.month + i, 1);
      final key =
          '${m.year}-${m.month.toString().padLeft(2, '0')}';
      result[key] = raw[key] ?? 0;
    }
    return result;
  }

  // ═══════════════════════════════════════════════════════════
  // GÉNÉALOGIE & CONSANGUINITÉ
  // ═══════════════════════════════════════════════════════════

  /// Retourne tous les ancêtres d'un lapin jusqu'à `depth` générations.
  /// Le lapin lui-même n'est PAS inclus dans le set retourné.
  Future<Set<int>> getAncetres(int lapinId, {int depth = 3}) async {
    final ancetres = <int>{};
    final aTraiter = <int>[lapinId];

    for (int gen = 0; gen < depth; gen++) {
      if (aTraiter.isEmpty) break;
      final placeholders = List.filled(aTraiter.length, '?').join(',');
      final rows = await db.rawQuery(
        'SELECT id, pere_id, mere_id FROM lapins WHERE id IN ($placeholders)',
        aTraiter,
      );
      final nouveaux = <int>[];
      for (final r in rows) {
        final pere = r['pere_id'] as int?;
        final mere = r['mere_id'] as int?;
        if (pere != null && ancetres.add(pere)) nouveaux.add(pere);
        if (mere != null && ancetres.add(mere)) nouveaux.add(mere);
      }
      aTraiter
        ..clear()
        ..addAll(nouveaux);
    }
    return ancetres;
  }

  /// Retourne le degré de parenté entre deux lapins, ou null si non apparentés.
  Future<String?> verifierConsanguinite(int aId, int bId, {int depth = 3}) async {
    if (aId == bId) return 'Même individu !';

    final ancetresA = await getAncetres(aId, depth: depth);
    final ancetresB = await getAncetres(bId, depth: depth);

    // Cas 1 : l'un est ancêtre direct de l'autre
    if (ancetresA.contains(bId)) return 'Parent/grand-parent direct';
    if (ancetresB.contains(aId)) return 'Enfant/petit-enfant direct';

    // Cas 2 : ancêtre commun
    final commun = ancetresA.intersection(ancetresB);
    if (commun.isEmpty) return null;

    // Identifier le degré : si parent commun direct → frère/sœur
    final aRow = await db.query('lapins', where: 'id = ?', whereArgs: [aId], columns: ['pere_id', 'mere_id']);
    final bRow = await db.query('lapins', where: 'id = ?', whereArgs: [bId], columns: ['pere_id', 'mere_id']);
    if (aRow.isNotEmpty && bRow.isNotEmpty) {
      final pereA = aRow.first['pere_id'];
      final mereA = aRow.first['mere_id'];
      final pereB = bRow.first['pere_id'];
      final mereB = bRow.first['mere_id'];
      final memesParents = pereA != null && mereA != null && pereA == pereB && mereA == mereB;
      final unParentCommun = (pereA != null && pereA == pereB) || (mereA != null && mereA == mereB);
      if (memesParents) return 'Frère/Sœur (mêmes parents)';
      if (unParentCommun) return 'Demi-frère/sœur (un parent commun)';
    }

    return 'Ancêtre commun jusqu\'à $depth générations';
  }
}
