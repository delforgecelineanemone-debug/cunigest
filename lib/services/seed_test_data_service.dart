// ──────────────────────────────────────────────────────────────
// Service : Données de test (V2.5)
// ──────────────────────────────────────────────────────────────
// Insère un jeu de données réaliste pour tester l'app :
// - 1 bâtiment, 2 clapiers, 8 cages
// - 12 lapins (statuts, sexes, âges, destinations variés)
// - 3 saillies (en attente, mise bas, sevrée → lot auto)
// - 1 lot d'engraissement actif
// - 2 ventes
// - 2 dépenses
// - 2 stocks
//
// Idempotent par marqueur : si un lapin de bague "TEST-LP-001" existe
// déjà, le seed est sauté (ré-insertion silencieuse).
// ──────────────────────────────────────────────────────────────

import '../database/db_helper.dart';
import '../models/batiment.dart';
import '../models/cage.dart';
import '../models/clapier.dart';
import '../models/depense.dart';
import '../models/lapin.dart';
import '../models/lot.dart';
import '../models/saillie.dart';
import '../models/stock.dart';
import '../models/vente.dart';

class SeedTestDataService {
  SeedTestDataService._();

  static const String _markerBague = 'TEST-LP-001';

  /// Insère le jeu de données. Renvoie un résumé (texte affichable).
  /// Si déjà inséré (présence du lapin marqueur), retourne 'Déjà inséré'.
  static Future<String> seed() async {
    final db = DBHelper.instance;
    final allLapins = await db.getAllLapins();
    if (allLapins.any((l) => l.numeroBague == _markerBague)) {
      return 'Données de test déjà présentes (skip).';
    }

    final today = DateTime.now();
    String iso(DateTime d) => d.toIso8601String().substring(0, 10);
    DateTime jMoins(int j) => today.subtract(Duration(days: j));

    // ── 1. Bâtiment + clapiers + cages ──
    final cagesRepo = await db.cages;
    final batId = await cagesRepo.insertBatiment(Batiment(
      nom: 'Bâtiment Test',
      adresse: 'Yaoundé, Cameroun',
      dateCreation: iso(today),
    ));
    final clapierAId = await cagesRepo.insertClapier(Clapier(
      nom: 'Clapier A (repro)',
      batimentId: batId,
      dateCreation: iso(today),
    ));
    final clapierBId = await cagesRepo.insertClapier(Clapier(
      nom: 'Clapier B (engraissement)',
      batimentId: batId,
      dateCreation: iso(today),
    ));
    final cageIds = <int>[];
    for (final num in ['A1', 'A2', 'A3', 'A4']) {
      cageIds.add(await cagesRepo.insertCage(Cage(
        numero: num,
        clapierId: clapierAId,
        capaciteMax: 1,
        dateCreation: iso(today),
      )));
    }
    for (final num in ['B1', 'B2', 'B3', 'B4']) {
      cageIds.add(await cagesRepo.insertCage(Cage(
        numero: num,
        clapierId: clapierBId,
        capaciteMax: 8,
        dateCreation: iso(today),
      )));
    }

    // ── 2. Lapins variés (12) ──
    // Reproducteurs adultes (parents pour la généalogie)
    final pere1Id = await db.insertLapin(Lapin(
      numeroBague: _markerBague,
      nom: 'Buck Max',
      sexe: 'male',
      race: 'Néo-Zélandais',
      dateNaissance: iso(jMoins(420)), // ~14 mois
      poids: 4.2,
      couleur: 'Blanc',
      cageId: cageIds[0],
      statut: 'actif',
      prixAchat: 25000,
      notes: 'Reproducteur principal',
    ));
    final mere1Id = await db.insertLapin(Lapin(
      numeroBague: 'TEST-LP-002',
      nom: 'Bella',
      sexe: 'femelle',
      race: 'Néo-Zélandaise',
      dateNaissance: iso(jMoins(390)),
      poids: 3.8,
      couleur: 'Blanc',
      cageId: cageIds[1],
      statut: 'actif',
      prixAchat: 22000,
    ));
    final mere2Id = await db.insertLapin(Lapin(
      numeroBague: 'TEST-LP-003',
      nom: 'Lola',
      sexe: 'femelle',
      race: 'Californienne',
      dateNaissance: iso(jMoins(350)),
      poids: 3.5,
      couleur: 'Blanc tachetée',
      cageId: cageIds[2],
      statut: 'actif',
    ));

    // Quarantaine (récente)
    await db.insertLapin(Lapin(
      numeroBague: 'TEST-LP-004',
      nom: 'Fleur',
      sexe: 'femelle',
      race: 'Rex',
      dateNaissance: iso(jMoins(180)),
      poids: 2.9,
      cageId: cageIds[3],
      statut: 'quarantaine',
      notes: 'Achetée la semaine dernière, période d\'observation',
    ));

    // Sevrage (3-4 mois)
    await db.insertLapin(Lapin(
      numeroBague: 'TEST-LP-005',
      sexe: 'male',
      race: 'Néo-Zélandais',
      dateNaissance: iso(jMoins(110)),
      poids: 2.1,
      pereId: pere1Id,
      mereId: mere1Id,
      cageId: cageIds[4],
      statut: 'sevrage',
    ));
    await db.insertLapin(Lapin(
      numeroBague: 'TEST-LP-006',
      sexe: 'femelle',
      race: 'Néo-Zélandaise',
      dateNaissance: iso(jMoins(105)),
      poids: 2.0,
      pereId: pere1Id,
      mereId: mere1Id,
      cageId: cageIds[4],
      statut: 'sevrage',
    ));

    // Lapereaux récents (60 jours — fenêtre sexage)
    await db.insertLapin(Lapin(
      numeroBague: 'TEST-LP-007',
      nom: 'Vif',
      sexe: 'male',
      race: 'Californien',
      dateNaissance: iso(jMoins(65)),
      poids: 1.4,
      pereId: pere1Id,
      mereId: mere2Id,
      cageId: cageIds[5],
      statut: 'actif',
    ));
    await db.insertLapin(Lapin(
      numeroBague: 'TEST-LP-008',
      sexe: 'femelle',
      race: 'Californienne',
      dateNaissance: iso(jMoins(62)),
      poids: 1.3,
      pereId: pere1Id,
      mereId: mere2Id,
      cageId: cageIds[5],
      statut: 'actif',
    ));

    // Reproducteur sélectionné (destination)
    await db.insertLapin(Lapin(
      numeroBague: 'TEST-LP-009',
      nom: 'Hermès',
      sexe: 'male',
      race: 'Néo-Zélandais',
      dateNaissance: iso(jMoins(220)),
      poids: 3.7,
      pereId: pere1Id,
      mereId: mere1Id,
      cageId: cageIds[6],
      statut: 'actif',
      destination: 'reproducteur',
      notes: 'Sélectionné comme futur reproducteur (excellents critères de croissance)',
    ));

    // Vendu
    await db.insertLapin(Lapin(
      numeroBague: 'TEST-LP-010',
      sexe: 'male',
      race: 'Néo-Zélandais',
      dateNaissance: iso(jMoins(130)),
      poids: 2.4,
      pereId: pere1Id,
      mereId: mere1Id,
      statut: 'vendu',
      destination: 'vendu',
    ));

    // Auto-consommé
    await db.insertLapin(Lapin(
      numeroBague: 'TEST-LP-011',
      sexe: 'femelle',
      race: 'Néo-Zélandaise',
      dateNaissance: iso(jMoins(125)),
      poids: 2.3,
      pereId: pere1Id,
      mereId: mere2Id,
      statut: 'vendu',
      destination: 'consomme',
    ));

    // Mort
    await db.insertLapin(Lapin(
      numeroBague: 'TEST-LP-012',
      sexe: 'male',
      dateNaissance: iso(jMoins(45)),
      poids: 0.8,
      pereId: pere1Id,
      mereId: mere1Id,
      statut: 'mort',
      notes: 'Décès post-sevrage (entérite suspectée)',
    ));

    // ── 3. Saillies à différents stades ──
    // Saillie en attente (J+5, palpation à venir)
    await db.insertSaillie(Saillie(
      mereId: mere1Id,
      pereId: pere1Id,
      dateSaillie: iso(jMoins(5)),
      dateMiseBasPrevue: iso(jMoins(5).add(const Duration(days: 31))),
      statut: 'en_attente',
      palpationPositive: false,
      nbChevauchements: 3,
    ));

    // Saillie avec mise bas faite (J+38) → auto-création lot
    final saillie2Id = await db.insertSaillie(Saillie(
      mereId: mere2Id,
      pereId: pere1Id,
      dateSaillie: iso(jMoins(38)),
      dateMiseBasPrevue: iso(jMoins(38).add(const Duration(days: 31))),
      dateMiseBasReelle: iso(jMoins(7)),
      nbNes: 8,
      nbVivants: 7,
      nbMorts: 1,
      statut: 'mise_bas',
      palpationPositive: true,
      nbChevauchements: 2,
      etatNid: 'Prêt — lapine s\'est arrachée les poils J+27',
    ));

    // Créer le lot lié à saillie2
    final lotsRepo = await db.lots;
    final lot2Id = await lotsRepo.insertLot(Lot(
      code: 'TEST-LT-2026-05-001',
      dateCreation: iso(jMoins(7)),
      nombreInitial: 7,
      saillieId: saillie2Id,
      notes: 'Lot auto-créé depuis la mise bas (test)',
    ));
    // Lier saillie ↔ lot
    final dbInstance = await db.database;
    await dbInstance.update(
      'saillies',
      {'lot_id': lot2Id},
      where: 'id = ?',
      whereArgs: [saillie2Id],
    );

    // Saillie terminée (sevrée il y a 2 semaines)
    await db.insertSaillie(Saillie(
      mereId: mere1Id,
      pereId: pere1Id,
      dateSaillie: iso(jMoins(110)),
      dateMiseBasPrevue: iso(jMoins(110).add(const Duration(days: 31))),
      dateMiseBasReelle: iso(jMoins(78)),
      nbNes: 9,
      nbVivants: 8,
      nbMorts: 1,
      nbSevres: 7,
      dateSevrage: iso(jMoins(40)),
      poidsSevrageTotal: 5.6,
      statut: 'termine',
      palpationPositive: true,
    ));

    // ── 4. Lot d'engraissement (manuel) ──
    await lotsRepo.insertLot(Lot(
      code: 'TEST-LT-2026-04-001',
      dateCreation: iso(jMoins(50)),
      cage: 'B3',
      nombreInitial: 12,
      poidsInitial: 9.6,
      notes: 'Lot test engraissement',
    ));

    // ── 5. Ventes ──
    await dbInstance.insert('ventes', Vente(
      lapinId: null,
      dateVente: iso(jMoins(15)),
      typeVente: 'poids_vif',
      acheteur: 'Boucher Mbarga',
      prixVente: 22500,
      poids: 9.0,
      quantite: 4,
      notes: 'Lot vendu en gros',
    ).toMap());
    await dbInstance.insert('ventes', Vente(
      lapinId: null,
      dateVente: iso(jMoins(3)),
      typeVente: 'carcasse',
      acheteur: 'Restaurant Le Lapin d\'Or',
      prixVente: 12000,
      poids: 4.8,
      quantite: 2,
    ).toMap());

    // ── 6. Dépenses ──
    await dbInstance.insert('depenses', Depense(
      dateDepense: iso(jMoins(20)),
      categorie: 'aliment',
      montant: 15000,
      description: 'Sac granulés 50 kg',
      dateCreation: iso(today),
    ).toMap());
    await dbInstance.insert('depenses', Depense(
      dateDepense: iso(jMoins(10)),
      categorie: 'soins',
      montant: 4500,
      description: 'Vaccin VHD x10 doses',
      dateCreation: iso(today),
    ).toMap());

    // ── 7. Stocks ──
    await dbInstance.insert('stocks', Stock(
      produit: 'Granulés lapins',
      typeAliment: 'granules',
      quantite: 42,
      unite: 'kg',
      quantiteMin: 50,
      dateEntree: iso(jMoins(20)),
      coutUnitaire: 300,
    ).toMap());
    await dbInstance.insert('stocks', Stock(
      produit: 'Foin de qualité',
      typeAliment: 'foin',
      quantite: 85,
      unite: 'kg',
      quantiteMin: 20,
      dateEntree: iso(jMoins(15)),
    ).toMap());

    return '✅ Données de test insérées :\n'
        '• 12 lapins (statuts/âges/destinations variés)\n'
        '• 1 bâtiment, 2 clapiers, 8 cages\n'
        '• 3 saillies (en attente / mise bas / terminée)\n'
        '• 2 lots, 2 ventes, 2 dépenses, 2 stocks';
  }
}
