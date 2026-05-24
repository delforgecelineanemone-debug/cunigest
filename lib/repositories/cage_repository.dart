// ──────────────────────────────────────────────────────────────
// Repository : Bâtiments / Clapiers / Cages (V2.2 — Phase 2)
// ──────────────────────────────────────────────────────────────
// Encapsule la logique métier des cages :
// - CRUD bâtiments / clapiers / cages
// - Compte d'occupation par cage (lapins actifs présents)
// - Déplacement transactionnel d'un lapin entre cages avec
//   enregistrement dans l'historique mouvements_cage
// - Calcul automatique du statut "vide" / "occupee" si non figé
//
// Toutes les écritures qui modifient `lapins.cage_id` passent par ce
// repo afin que l'historique reste cohérent.
// ──────────────────────────────────────────────────────────────

import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/batiment.dart';
import '../models/clapier.dart';
import '../models/cage.dart';
import '../models/mouvement_cage.dart';
import '../models/lapin.dart';
import '../services/data_bus.dart';
import 'sync_meta.dart';

class CageRepository {
  final Database db;
  final Future<void> Function(String, int, String, Map<String, dynamic>)?
      enqueueSyncIfEnabled;

  CageRepository(this.db, {this.enqueueSyncIfEnabled});

  // ── Bâtiments ──

  Future<int> insertBatiment(Batiment b) async {
    final m = stampUpdated(b.toMap()..remove('id'));
    final id = await db.insert('batiments', m);
    await enqueueSyncIfEnabled?.call(
        'batiments', id, 'insert', {...m, 'id': id});
    DataBus.instance.notify(DataTopics.batiments);
    return id;
  }

  Future<List<Batiment>> getAllBatiments() async {
    final maps = await db.query('batiments',
        where: kNotDeletedWhere, orderBy: 'nom ASC');
    return maps.map(Batiment.fromMap).toList();
  }

  Future<Batiment?> getBatimentById(int id) async {
    final maps = await db.query('batiments',
        where: 'id = ? AND $kNotDeletedWhere', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Batiment.fromMap(maps.first);
  }

  Future<int> updateBatiment(Batiment b) async {
    final payload = stampUpdated(b.toMap()..remove('id'));
    final r = await db.update(
      'batiments',
      payload,
      where: 'id = ?',
      whereArgs: [b.id],
    );
    if (b.id != null) {
      await enqueueSyncIfEnabled?.call(
          'batiments', b.id!, 'update', stampUpdated(b.toMap()));
    }
    DataBus.instance.notify(DataTopics.batiments);
    return r;
  }

  Future<int> deleteBatiment(int id) async {
    final r = await softDelete(db, 'batiments', id);
    await enqueueSyncIfEnabled?.call('batiments', id, 'delete', {'id': id, 'deleted_at': nowIso()});
    DataBus.instance.notify(DataTopics.batiments);
    return r;
  }

  // ── Clapiers ──

  Future<int> insertClapier(Clapier c) async {
    final m = stampUpdated(c.toMap()..remove('id'));
    final id = await db.insert('clapiers', m);
    await enqueueSyncIfEnabled?.call(
        'clapiers', id, 'insert', {...m, 'id': id});
    DataBus.instance.notify(DataTopics.clapiers);
    return id;
  }

  Future<List<Clapier>> getClapiersByBatiment(int batimentId) async {
    final maps = await db.query(
      'clapiers',
      where: 'batiment_id = ? AND $kNotDeletedWhere',
      whereArgs: [batimentId],
      orderBy: 'nom ASC',
    );
    return maps.map(Clapier.fromMap).toList();
  }

  Future<Clapier?> getClapierById(int id) async {
    final maps = await db.query('clapiers',
        where: 'id = ? AND $kNotDeletedWhere', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Clapier.fromMap(maps.first);
  }

  Future<int> updateClapier(Clapier c) async {
    final payload = stampUpdated(c.toMap()..remove('id'));
    final r = await db.update(
      'clapiers',
      payload,
      where: 'id = ?',
      whereArgs: [c.id],
    );
    if (c.id != null) {
      await enqueueSyncIfEnabled?.call(
          'clapiers', c.id!, 'update', stampUpdated(c.toMap()));
    }
    DataBus.instance.notify(DataTopics.clapiers);
    return r;
  }

  Future<int> deleteClapier(int id) async {
    final r = await softDelete(db, 'clapiers', id);
    await enqueueSyncIfEnabled?.call('clapiers', id, 'delete', {'id': id, 'deleted_at': nowIso()});
    DataBus.instance.notify(DataTopics.clapiers);
    return r;
  }

  // ── Cages ──

  Future<int> insertCage(Cage c) async {
    final m = stampUpdated(c.toMap()..remove('id'));
    final id = await db.insert('cages', m);
    await enqueueSyncIfEnabled?.call('cages', id, 'insert', {...m, 'id': id});
    DataBus.instance.notify(DataTopics.cages);
    return id;
  }

  Future<List<Cage>> getCagesByClapier(int clapierId) async {
    final maps = await db.query(
      'cages',
      where: 'clapier_id = ? AND $kNotDeletedWhere',
      whereArgs: [clapierId],
      orderBy: 'numero ASC',
    );
    return maps.map(Cage.fromMap).toList();
  }

  Future<List<Cage>> getAllCages() async {
    final maps = await db.query('cages',
        where: kNotDeletedWhere, orderBy: 'numero ASC');
    return maps.map(Cage.fromMap).toList();
  }

  Future<Cage?> getCageById(int id) async {
    final maps = await db.query('cages',
        where: 'id = ? AND $kNotDeletedWhere', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Cage.fromMap(maps.first);
  }

  Future<int> updateCage(Cage c) async {
    final payload = stampUpdated(c.toMap()..remove('id'));
    final r = await db.update(
      'cages',
      payload,
      where: 'id = ?',
      whereArgs: [c.id],
    );
    if (c.id != null) {
      await enqueueSyncIfEnabled?.call(
          'cages', c.id!, 'update', stampUpdated(c.toMap()));
    }
    DataBus.instance.notify(DataTopics.cages);
    return r;
  }

  Future<int> deleteCage(int id) async {
    final r = await softDelete(db, 'cages', id);
    await enqueueSyncIfEnabled?.call('cages', id, 'delete', {'id': id, 'deleted_at': nowIso()});
    DataBus.instance.notify(DataTopics.cages);
    return r;
  }

  // ── Occupation ──

  /// Renvoie les lapins actuellement présents dans la cage (statut != mort/vendu).
  Future<List<Lapin>> getOccupants(int cageId) async {
    final maps = await db.query(
      'lapins',
      where: "cage_id = ? AND statut NOT IN ('mort', 'vendu') AND $kNotDeletedWhere",
      whereArgs: [cageId],
      orderBy: 'numero_bague ASC',
    );
    return maps.map(Lapin.fromMap).toList();
  }

  /// Compte d'occupants présents par cage (id → nombre).
  Future<Map<int, int>> countOccupantsByCage() async {
    final rows = await db.rawQuery('''
      SELECT cage_id, COUNT(*) AS n
      FROM lapins
      WHERE cage_id IS NOT NULL AND statut NOT IN ('mort', 'vendu') AND deleted_at IS NULL
      GROUP BY cage_id
    ''');
    return {
      for (final r in rows) (r['cage_id'] as int): (r['n'] as int),
    };
  }

  // ── Déplacements (historique) ──

  /// Déplace un lapin vers une nouvelle cage (transactionnel).
  /// - Vérifie la capacité max de la cage de destination
  /// - Met à jour `lapins.cage_id`
  /// - Insère un MouvementCage dans l'historique
  /// - Met à jour le statut de la cage de destination si "vide" → "occupee"
  /// Renvoie l'id du mouvement créé.
  ///
  /// Lance [Exception] si la cage destination est pleine.
  Future<int> deplacerLapin({
    required int lapinId,
    required int? cageDestinationId,
    String? motif,
    String? notes,
  }) async {
    final now = nowIso();
    return await db.transaction<int>((txn) async {
      // 1. État actuel
      final lapinRows = await txn.query('lapins',
          where: 'id = ? AND deleted_at IS NULL', whereArgs: [lapinId], limit: 1);
      if (lapinRows.isEmpty) {
        throw Exception('Lapin introuvable (id=$lapinId)');
      }
      final cageOrigineId = lapinRows.first['cage_id'] as int?;

      // No-op si même cage
      if (cageOrigineId == cageDestinationId) {
        throw Exception('Le lapin est déjà dans cette cage.');
      }

      // 2. Vérifier capacité destination
      if (cageDestinationId != null) {
        final destRows = await txn.query('cages',
            where: 'id = ? AND deleted_at IS NULL', whereArgs: [cageDestinationId], limit: 1);
        if (destRows.isEmpty) {
          throw Exception('Cage destination introuvable.');
        }
        final cap = (destRows.first['capacite_max'] as int?) ?? 1;
        final count = Sqflite.firstIntValue(await txn.rawQuery(
              "SELECT COUNT(*) FROM lapins WHERE cage_id = ? AND statut NOT IN ('mort','vendu') AND deleted_at IS NULL",
              [cageDestinationId],
            )) ??
            0;
        if (count >= cap) {
          final numero = destRows.first['numero'];
          throw Exception(
              'Cage $numero pleine ($count/$cap). Capacité max atteinte.');
        }
      }

      // 3. Mise à jour du lapin
      await txn.update(
        'lapins',
        {'cage_id': cageDestinationId, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [lapinId],
      );

      // 4. Auto-statut : si destination passe de vide à occupée
      if (cageDestinationId != null) {
        final destRows = await txn.query('cages',
            where: 'id = ?', whereArgs: [cageDestinationId], limit: 1);
        if (destRows.isNotEmpty && destRows.first['statut'] == 'vide') {
          await txn.update('cages', {'statut': 'occupee', 'updated_at': now},
              where: 'id = ?', whereArgs: [cageDestinationId]);
        }
      }

      // 5. Auto-statut : si origine se retrouve vide ET statut était "occupee"
      if (cageOrigineId != null) {
        final remaining = Sqflite.firstIntValue(await txn.rawQuery(
              "SELECT COUNT(*) FROM lapins WHERE cage_id = ? AND statut NOT IN ('mort','vendu') AND deleted_at IS NULL",
              [cageOrigineId],
            )) ??
            0;
        if (remaining == 0) {
          final orig = await txn.query('cages',
              where: 'id = ?', whereArgs: [cageOrigineId], limit: 1);
          if (orig.isNotEmpty && orig.first['statut'] == 'occupee') {
            await txn.update('cages', {'statut': 'vide', 'updated_at': now},
                where: 'id = ?', whereArgs: [cageOrigineId]);
          }
        }
      }

      // 6. Historique
      final mvt = MouvementCage(
        lapinId: lapinId,
        cageOrigineId: cageOrigineId,
        cageDestinationId: cageDestinationId,
        motif: motif,
        notes: notes,
      );
      return await txn.insert('mouvements_cage',
          stampUpdated(mvt.toMap()..remove('id')));
    }).then((mvtId) async {
      // Enqueue les changements dans sync_queue (hors transaction).
      // Récupère le lapin mis à jour (cage_id) pour le payload complet.
      final lapinRows = await db.query('lapins',
          where: 'id = ?', whereArgs: [lapinId], limit: 1);
      if (lapinRows.isNotEmpty) {
        await enqueueSyncIfEnabled?.call(
            'lapins', lapinId, 'update', lapinRows.first);
      }
      final mvtRows = await db.query('mouvements_cage',
          where: 'id = ?', whereArgs: [mvtId], limit: 1);
      if (mvtRows.isNotEmpty) {
        await enqueueSyncIfEnabled?.call(
            'mouvements_cage', mvtId, 'insert', mvtRows.first);
      }
      // Le déplacement touche 3 tables → notifier les trois topics UI.
      DataBus.instance.notify(DataTopics.cages);
      DataBus.instance.notify(DataTopics.lapins);
      DataBus.instance.notify(DataTopics.mouvementsCage);
      return mvtId;
    });
  }

  /// Historique des mouvements d'un lapin (du plus récent au plus ancien).
  Future<List<MouvementCage>> getHistoriqueLapin(int lapinId) async {
    final maps = await db.query(
      'mouvements_cage',
      where: 'lapin_id = ?',
      whereArgs: [lapinId],
      orderBy: 'date DESC, id DESC',
    );
    return maps.map(MouvementCage.fromMap).toList();
  }

  /// Historique des mouvements d'une cage (entrées + sorties).
  Future<List<MouvementCage>> getHistoriqueCage(int cageId) async {
    final maps = await db.query(
      'mouvements_cage',
      where: 'cage_origine_id = ? OR cage_destination_id = ?',
      whereArgs: [cageId, cageId],
      orderBy: 'date DESC, id DESC',
    );
    return maps.map(MouvementCage.fromMap).toList();
  }
}
