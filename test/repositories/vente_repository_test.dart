// Tests : VenteRepository — atomicité vente↔statut lapin + top clients.
// Risque cible : insertVente est transactionnelle (la vente passe le
// lapin en 'vendu'). En cas d'erreur, ni l'un ni l'autre ne doit
// rester. getTopClients doit ignorer les ventes anonymes pour ne pas
// fausser le classement.

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/models/vente.dart';
import 'package:gestion_cunicole/repositories/vente_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

void main() {
  late Database db;
  late VenteRepository repo;

  setUp(() async {
    db = await openTestDb();
    repo = VenteRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> addLapin(String bague) {
    return db.insert('lapins', {
      'numero_bague': bague, 'sexe': 'male', 'statut': 'actif',
      'date_creation': '2026-01-01',
    });
  }

  /// Crée un lot (FK ventes.lot_id → lots.id active) et renvoie son id.
  Future<int> addLot(String code) {
    return db.insert('lots', {
      'code': code,
      'date_creation': '2026-01-01',
      'nombre_initial': 10,
      'statut': 'en_cours',
    });
  }

  group('insertVente — effet sur le lapin', () {
    test('vente d\'un lapin individuel → statut passe à "vendu"', () async {
      final lId = await addLapin('A');
      await repo.insertVente(Vente(
        lapinId: lId, dateVente: '2026-05-01',
        typeVente: 'vivant', prixVente: 25.0,
      ));
      final l = (await db.query('lapins', where: 'id = ?', whereArgs: [lId])).first;
      expect(l['statut'], 'vendu');
    });

    test('vente sans lapinId (lot) → aucun statut modifié', () async {
      final lId = await addLapin('B');
      final lotId = await addLot('LT-A');
      await repo.insertVente(Vente(
        lapinId: null, lotId: lotId, dateVente: '2026-05-01',
        typeVente: 'lapereau', prixVente: 100.0, quantite: 10,
      ));
      final l = (await db.query('lapins', where: 'id = ?', whereArgs: [lId])).first;
      expect(l['statut'], 'actif');
    });
  });

  group('totalParLot / totalParLapin', () {
    test('totalParLot somme toutes les ventes du lot', () async {
      final lot7 = await addLot('LT-7');
      final lot8 = await addLot('LT-8');
      await repo.insertVente(Vente(
        lotId: lot7, dateVente: '2026-05-01', typeVente: 'lapereau',
        prixVente: 50.0,
      ));
      await repo.insertVente(Vente(
        lotId: lot7, dateVente: '2026-05-02', typeVente: 'lapereau',
        prixVente: 75.5,
      ));
      await repo.insertVente(Vente(
        lotId: lot8, dateVente: '2026-05-03', typeVente: 'lapereau',
        prixVente: 200,
      )); // autre lot
      expect(await repo.totalParLot(lot7), 125.5);
      expect(await repo.totalParLot(9999), 0.0);
    });
  });

  group('getTopClients', () {
    test('exclut acheteurs null et chaînes vides', () async {
      await repo.insertVente(Vente(
        dateVente: '2026-05-01', typeVente: 'vivant',
        prixVente: 100, acheteur: null,
      ));
      await repo.insertVente(Vente(
        dateVente: '2026-05-01', typeVente: 'vivant',
        prixVente: 100, acheteur: '',
      ));
      await repo.insertVente(Vente(
        dateVente: '2026-05-01', typeVente: 'vivant',
        prixVente: 100, acheteur: '   ',
      ));
      await repo.insertVente(Vente(
        dateVente: '2026-05-01', typeVente: 'vivant',
        prixVente: 50, acheteur: 'Dupont',
      ));

      final top = await repo.getTopClients(from: '2026-01-01', to: '2026-12-31');
      expect(top.length, 1);
      expect(top.first['nom'], 'Dupont');
    });

    test('groupe par acheteur, trie par CA décroissant', () async {
      await repo.insertVente(Vente(
        dateVente: '2026-05-01', typeVente: 'vivant',
        prixVente: 30, acheteur: 'A',
      ));
      await repo.insertVente(Vente(
        dateVente: '2026-05-02', typeVente: 'vivant',
        prixVente: 70, acheteur: 'A',
      ));
      await repo.insertVente(Vente(
        dateVente: '2026-05-01', typeVente: 'vivant',
        prixVente: 200, acheteur: 'B',
      ));

      final top = await repo.getTopClients(from: '2026-01-01', to: '2026-12-31');
      expect(top.first['nom'], 'B');
      expect(top.first['total'], 200.0);
      expect(top[1]['nom'], 'A');
      expect(top[1]['total'], 100.0);
      expect(top[1]['nb_ventes'], 2);
    });

    test('respect des bornes from/to', () async {
      await repo.insertVente(Vente(
        dateVente: '2026-01-15', typeVente: 'vivant',
        prixVente: 100, acheteur: 'Hors',
      ));
      await repo.insertVente(Vente(
        dateVente: '2026-05-15', typeVente: 'vivant',
        prixVente: 50, acheteur: 'Dans',
      ));
      final top = await repo.getTopClients(
          from: '2026-05-01', to: '2026-05-31');
      expect(top.length, 1);
      expect(top.first['nom'], 'Dans');
    });
  });

  group('getStatistiquesVentes', () {
    test('base vide → 0 partout (pas de null)', () async {
      final s = await repo.getStatistiquesVentes();
      expect(s['nombre_total'], 0);
      expect(s['chiffre_affaires_total'], 0.0);
      expect(s['chiffre_affaires_mois'], 0.0);
    });
  });
}
