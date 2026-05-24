// ──────────────────────────────────────────────────────────────
// Repository : Lots d'engraissement
// ──────────────────────────────────────────────────────────────
// Encapsule toute la logique métier des lots :
// - CRUD lots / pesées / distributions d'aliment
// - Calcul du GMQ (Gain Moyen Quotidien)
// - Calcul de l'IC (Indice de Consommation)
//
// Le GMQ est exprimé en grammes par jour par lapereau :
//   GMQ = ((poids_actuel - poids_initial) * 1000) / (jours * nombre)
//
// L'IC est l'aliment consommé pour produire 1 kg de poids vif :
//   IC = total_aliment_kg / (poids_produit_kg)
//        avec poids_produit = poids_actuel - poids_initial
//
// Bonnes valeurs de référence (souches productives) :
//   GMQ : 35-45 g/j en croissance (28-77 jours d'âge)
//   IC  : 3.0 à 3.5 (kg aliment / kg vif)
// ──────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/lot.dart';
import '../services/data_bus.dart';
import 'sync_meta.dart';

class LotRepository {
  final Database db;
  LotRepository(this.db);

  // ── Lots ──

  Future<int> insertLot(Lot lot) async {
    final payload = stampUpdated(lot.toMap());
    final id = await db.insert('lots', payload);
    await _enqueueSyncIfEnabled('lots', id, 'insert', {...payload, 'id': id});
    DataBus.instance.notify(DataTopics.lots);
    return id;
  }

  Future<List<Lot>> getAll() async {
    final maps = await db.query('lots',
        where: kNotDeletedWhere, orderBy: 'date_creation DESC');
    return maps.map((m) => Lot.fromMap(m)).toList();
  }

  Future<List<Lot>> getEnCours() async {
    final maps = await db.query('lots',
        where: 'statut = ? AND $kNotDeletedWhere',
        whereArgs: ['en_cours'],
        orderBy: 'date_creation DESC');
    return maps.map((m) => Lot.fromMap(m)).toList();
  }

  Future<Lot?> getById(int id) async {
    final maps = await db.query('lots',
        where: 'id = ? AND $kNotDeletedWhere', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Lot.fromMap(maps.first);
  }

  Future<int> update(Lot lot) async {
    final payload = stampUpdated(lot.toMap());
    final r = await db.update('lots', payload, where: 'id = ?', whereArgs: [lot.id]);
    if (lot.id != null) {
      await _enqueueSyncIfEnabled('lots', lot.id!, 'update', payload);
    }
    DataBus.instance.notify(DataTopics.lots);
    return r;
  }

  Future<int> delete(int id) async {
    final r = await softDelete(db, 'lots', id);
    await _enqueueSyncIfEnabled('lots', id, 'delete', {'id': id, 'deleted_at': nowIso()});
    DataBus.instance.notify(DataTopics.lots);
    return r;
  }

  Future<int> terminer(int id, String dateFin) async {
    final now = nowIso();
    final r = await db.update(
      'lots',
      {'statut': 'termine', 'date_fin': dateFin, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
    final lot = await getById(id);
    if (lot != null) {
      await _enqueueSyncIfEnabled('lots', id, 'update', stampUpdated(lot.toMap()));
    }
    DataBus.instance.notify(DataTopics.lots);
    return r;
  }

  // ── Pesées ──

  Future<int> insertPesee(Pesee p) async {
    final payload = stampUpdated(p.toMap());
    final id = await db.insert('pesees', payload);
    await _enqueueSyncIfEnabled('pesees', id, 'insert', {...payload, 'id': id});
    DataBus.instance.notify(DataTopics.pesees);
    return id;
  }

  Future<List<Pesee>> getPeseesByLot(int lotId) async {
    final maps = await db.query('pesees',
        where: 'lot_id = ? AND $kNotDeletedWhere',
        whereArgs: [lotId],
        orderBy: 'date_pesee ASC');
    return maps.map((m) => Pesee.fromMap(m)).toList();
  }

  Future<int> deletePesee(int id) async {
    final r = await softDelete(db, 'pesees', id);
    await _enqueueSyncIfEnabled('pesees', id, 'delete', {'id': id, 'deleted_at': nowIso()});
    DataBus.instance.notify(DataTopics.pesees);
    return r;
  }

  // ── Distributions d'aliment ──

  Future<int> insertDistribution(DistributionAliment d) async {
    final payload = stampUpdated(d.toMap());
    final id = await db.insert('distributions_aliment', payload);
    await _enqueueSyncIfEnabled(
      'distributions_aliment',
      id,
      'insert',
      {...payload, 'id': id},
    );
    DataBus.instance.notify(DataTopics.distributionsAliment);
    return id;
  }

  Future<List<DistributionAliment>> getDistributionsByLot(int lotId) async {
    final maps = await db.query('distributions_aliment',
        where: 'lot_id = ? AND $kNotDeletedWhere',
        whereArgs: [lotId],
        orderBy: 'date_distribution ASC');
    return maps.map((m) => DistributionAliment.fromMap(m)).toList();
  }

  Future<int> deleteDistribution(int id) async {
    final r = await softDelete(db, 'distributions_aliment', id);
    await _enqueueSyncIfEnabled('distributions_aliment', id, 'delete', {'id': id, 'deleted_at': nowIso()});
    DataBus.instance.notify(DataTopics.distributionsAliment);
    return r;
  }

  Future<void> _enqueueSyncIfEnabled(
    String tableName,
    int rowId,
    String operation,
    Map<String, dynamic> payload,
  ) async {
    try {
      final cfg = await db.query('sync_config', where: 'id = ?', whereArgs: [1], limit: 1);
      if (cfg.isEmpty || cfg.first['enabled'] != 1) return;
      await db.insert('sync_queue', {
        'table_name': tableName,
        'row_id': rowId,
        'operation': operation,
        'payload_json': jsonEncode(payload),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
      });
    } catch (_) {
      // La sync ne doit jamais bloquer une opération métier locale.
    }
  }

  // ── Lapins du lot ──

  Future<int> ajouterLapin(int lotId, int lapinId, String dateEntree) async {
    final r = await db.insert(
      'lot_lapins',
      {
        'lot_id': lotId,
        'lapin_id': lapinId,
        'date_entree': dateEntree,
        'updated_at': nowIso(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    DataBus.instance.notify(DataTopics.lots);
    return r;
  }

  Future<int> retirerLapin(int lotId, int lapinId, String dateSortie, String motif) async {
    final r = await db.update(
      'lot_lapins',
      {'date_sortie': dateSortie, 'motif_sortie': motif, 'updated_at': nowIso()},
      where: 'lot_id = ? AND lapin_id = ?',
      whereArgs: [lotId, lapinId],
    );
    DataBus.instance.notify(DataTopics.lots);
    return r;
  }

  Future<List<int>> getLapinIdsDuLot(int lotId, {bool seulementPresents = true}) async {
    final maps = await db.query(
      'lot_lapins',
      where: seulementPresents
          ? 'lot_id = ? AND date_sortie IS NULL AND $kNotDeletedWhere'
          : 'lot_id = ? AND $kNotDeletedWhere',
      whereArgs: [lotId],
    );
    return maps.map((m) => m['lapin_id'] as int).toList();
  }

  // ── Statistiques (GMQ + IC) ──

  /// Calcule les statistiques d'un lot : GMQ, IC, nb actuel, jours d'élevage.
  Future<LotStats> getStats(int lotId) async {
    final lot = await getById(lotId);
    if (lot == null) {
      return const LotStats(
        nombreActuel: 0,
        alimentTotalKg: 0,
        joursElevage: 0,
      );
    }

    final pesees = await getPeseesByLot(lotId);
    final distributions = await getDistributionsByLot(lotId);

    final dateCreation = DateTime.tryParse(lot.dateCreation) ?? DateTime.now();
    final dateRef = lot.dateFin != null
        ? (DateTime.tryParse(lot.dateFin!) ?? DateTime.now())
        : DateTime.now();
    final joursElevage = dateRef.difference(dateCreation).inDays;

    // Total aliment distribué
    final alimentTotalKg = distributions.fold<double>(
      0,
      (sum, d) => sum + d.quantiteKg,
    );

    // Dernière pesée (pour poids actuel + nombre actuel)
    Pesee? derniere;
    if (pesees.isNotEmpty) derniere = pesees.last;

    final nombreActuel = derniere?.nombre ?? lot.nombreInitial;
    final poidsActuel = derniere?.poidsTotal;

    // GMQ (g/jour/lapereau)
    double? gmq;
    if (poidsActuel != null && lot.poidsInitial != null && joursElevage > 0 && nombreActuel > 0) {
      final gainKg = poidsActuel - lot.poidsInitial!;
      // gain en grammes / jours / lapereaux
      gmq = (gainKg * 1000) / (joursElevage * nombreActuel);
    }

    // IC = aliment / poids vif produit
    double? ic;
    if (poidsActuel != null && lot.poidsInitial != null && alimentTotalKg > 0) {
      final poidsProduit = poidsActuel - lot.poidsInitial!;
      if (poidsProduit > 0) {
        ic = alimentTotalKg / poidsProduit;
      }
    }

    return LotStats(
      nombreActuel: nombreActuel,
      poidsActuel: poidsActuel,
      gmq: gmq,
      ic: ic,
      alimentTotalKg: alimentTotalKg,
      joursElevage: joursElevage,
    );
  }
}
