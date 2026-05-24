// ──────────────────────────────────────────────────────────────
// Service : Données de test (V2.5 — jeu de données étendu)
// ──────────────────────────────────────────────────────────────
// Insère un jeu de données réaliste et COMPLET pour tester toute
// l'application :
// - 1 bâtiment, 3 clapiers, 12 cages
// - ~24 lapins (tous les statuts, âges, destinations, causes de mortalité)
// - 6 saillies (en attente, palpation négative, mise bas, échec, terminée)
// - 8 soins (vaccins collectifs, rappel à venir, délai d'attente ACTIF…)
// - pesées individuelles (courbes de croissance) pour 3 lapereaux
// - 3 lots d'engraissement + pesées de lot + distributions d'aliment
// - 7 tâches de routine (quotidiennes, hebdo, mensuelle, ponctuelle)
// - 6 ventes, 8 dépenses, 6 stocks (dont un sous le seuil + un périmé)
//
// Idempotent par marqueur : si un lapin de bague "TEST-LP-001" existe
// déjà, le seed est sauté.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';
import '../models/batiment.dart';
import '../models/cage.dart';
import '../models/clapier.dart';
import '../models/depense.dart';
import '../models/lapin.dart';
import '../models/lot.dart';
import '../models/pesee_lapin.dart';
import '../models/saillie.dart';
import '../models/soin.dart';
import '../models/stock.dart';
import '../models/tache.dart';
import '../models/vente.dart';

class SeedTestDataService {
  SeedTestDataService._();

  static const String _markerBague = 'TEST-LP-001';

  /// Insère le jeu de données. Renvoie un résumé (texte affichable).
  /// Si déjà inséré (présence du lapin marqueur), retourne 'Déjà inséré'.
  ///
  /// RÉSERVÉ AUX BUILDS DEBUG/PROFILE. Bloqué en release pour éviter
  /// l'insertion accidentelle de données fictives dans un élevage réel.
  static Future<String> seed() async {
    if (kReleaseMode) {
      throw StateError(
        'SeedTestDataService.seed() est réservé aux builds debug/profile.',
      );
    }
    assert(!kReleaseMode,
        'SeedTestDataService ne doit pas être appelé en release.');
    final db = DBHelper.instance;
    final lapinsRepo = await db.lapins;
    final sailliesRepo = await db.saillies;
    final cagesRepo = await db.cages;
    final soinsRepo = await db.soins;
    final peseesRepo = await db.peseesLapin;
    final routinesRepo = await db.routines;
    final lotsRepo = await db.lots;
    final dbInstance = await db.database;

    final allLapins = await lapinsRepo.getAllLapins();
    if (allLapins.any((l) => l.numeroBague == _markerBague)) {
      return 'Données de test déjà présentes (skip).';
    }

    final today = DateTime.now();
    String iso(DateTime d) => d.toIso8601String().substring(0, 10);
    DateTime jMoins(int j) => today.subtract(Duration(days: j));
    DateTime jPlus(int j) => today.add(Duration(days: j));

    // ══════════════════════════════════════════════════════════
    // 1. BÂTIMENT + CLAPIERS + CAGES
    // ══════════════════════════════════════════════════════════
    final batId = await cagesRepo.insertBatiment(Batiment(
      nom: 'Bâtiment Principal',
      adresse: 'Yaoundé, Cameroun',
      dateCreation: iso(today),
    ));
    final clapierA = await cagesRepo.insertClapier(Clapier(
      nom: 'Clapier A — Reproduction',
      batimentId: batId,
      dateCreation: iso(today),
    ));
    final clapierB = await cagesRepo.insertClapier(Clapier(
      nom: 'Clapier B — Engraissement',
      batimentId: batId,
      dateCreation: iso(today),
    ));
    final clapierC = await cagesRepo.insertClapier(Clapier(
      nom: 'Clapier C — Quarantaine',
      batimentId: batId,
      dateCreation: iso(today),
    ));

    // Cages repro (capacité 1 — cages individuelles)
    final cageA = <int>[];
    for (final num in ['A1', 'A2', 'A3', 'A4', 'A5', 'A6']) {
      cageA.add(await cagesRepo.insertCage(Cage(
        numero: num,
        clapierId: clapierA,
        capaciteMax: 1,
        dateCreation: iso(today),
      )));
    }
    // Cages engraissement (capacité 10 — collectives)
    final cageB = <int>[];
    for (final num in ['B1', 'B2', 'B3', 'B4', 'B5']) {
      cageB.add(await cagesRepo.insertCage(Cage(
        numero: num,
        clapierId: clapierB,
        capaciteMax: 10,
        dateCreation: iso(today),
      )));
    }
    // Cage quarantaine
    final cageC1 = await cagesRepo.insertCage(Cage(
      numero: 'C1',
      clapierId: clapierC,
      capaciteMax: 5,
      dateCreation: iso(today),
    ));

    // ══════════════════════════════════════════════════════════
    // 2. LAPINS (~24 — tous les statuts représentés)
    // ══════════════════════════════════════════════════════════

    // ── Reproducteurs adultes ──
    final pere1 = await lapinsRepo.insertLapin(Lapin(
      numeroBague: _markerBague,
      nom: 'Buck Max',
      sexe: 'male',
      race: 'Néo-Zélandais',
      dateNaissance: iso(jMoins(450)),
      poids: 4.3,
      couleur: 'Blanc',
      cageId: cageA[0],
      statut: 'reproducteur',
      prixAchat: 25000,
      notes: 'Reproducteur principal — excellente fertilité',
    ));
    final pere2 = await lapinsRepo.insertLapin(Lapin(
      numeroBague: 'TEST-LP-002',
      nom: 'Duc',
      sexe: 'male',
      race: 'Californien',
      dateNaissance: iso(jMoins(320)),
      poids: 4.0,
      couleur: 'Blanc points noirs',
      cageId: cageA[1],
      statut: 'reproducteur',
      prixAchat: 23000,
      notes: 'Second mâle — rotation génétique',
    ));
    final mere1 = await lapinsRepo.insertLapin(Lapin(
      numeroBague: 'TEST-LP-003',
      nom: 'Bella',
      sexe: 'femelle',
      race: 'Néo-Zélandaise',
      dateNaissance: iso(jMoins(400)),
      poids: 3.9,
      couleur: 'Blanc',
      cageId: cageA[2],
      statut: 'reproducteur',
      prixAchat: 22000,
    ));
    final mere2 = await lapinsRepo.insertLapin(Lapin(
      numeroBague: 'TEST-LP-004',
      nom: 'Lola',
      sexe: 'femelle',
      race: 'Californienne',
      dateNaissance: iso(jMoins(360)),
      poids: 3.6,
      couleur: 'Blanc tachetée',
      cageId: cageA[3],
      statut: 'reproducteur',
    ));
    final mere3 = await lapinsRepo.insertLapin(Lapin(
      numeroBague: 'TEST-LP-005',
      nom: 'Noisette',
      sexe: 'femelle',
      race: 'Fauve de Bourgogne',
      dateNaissance: iso(jMoins(300)),
      poids: 3.7,
      couleur: 'Fauve',
      cageId: cageA[4],
      statut: 'reproducteur',
      prixAchat: 20000,
    ));
    await lapinsRepo.insertLapin(Lapin(
      numeroBague: 'TEST-LP-006',
      nom: 'Caramel',
      sexe: 'femelle',
      race: 'Fauve de Bourgogne',
      dateNaissance: iso(jMoins(280)),
      poids: 3.5,
      couleur: 'Fauve',
      cageId: cageA[5],
      statut: 'reproducteur',
    ));

    // ── Quarantaine (achats récents en observation) ──
    await lapinsRepo.insertLapin(Lapin(
      numeroBague: 'TEST-LP-007',
      nom: 'Fleur',
      sexe: 'femelle',
      race: 'Rex',
      dateNaissance: iso(jMoins(190)),
      poids: 3.0,
      cageId: cageC1,
      statut: 'quarantaine',
      prixAchat: 18000,
      notes: 'Achetée chez un éleveur voisin — observation 14 j',
    ));
    await lapinsRepo.insertLapin(Lapin(
      numeroBague: 'TEST-LP-008',
      nom: 'Réglisse',
      sexe: 'male',
      race: 'Rex',
      dateNaissance: iso(jMoins(200)),
      poids: 3.1,
      cageId: cageC1,
      statut: 'quarantaine',
      prixAchat: 19000,
      notes: 'Futur reproducteur — quarantaine en cours',
    ));

    // ── Jeunes au sevrage (issus de Buck Max × Bella) ──
    for (var i = 9; i <= 12; i++) {
      await lapinsRepo.insertLapin(Lapin(
        numeroBague: 'TEST-LP-${i.toString().padLeft(3, '0')}',
        sexe: i.isEven ? 'femelle' : 'male',
        race: 'Néo-Zélandais',
        dateNaissance: iso(jMoins(112)),
        poids: 1.9 + (i - 9) * 0.1,
        pereId: pere1,
        mereId: mere1,
        cageId: cageB[0],
        statut: 'sevrage',
      ));
    }

    // ── Lapins en engraissement (croissance suivie par pesées) ──
    final engr1 = await lapinsRepo.insertLapin(Lapin(
      numeroBague: 'TEST-LP-013',
      sexe: 'male',
      race: 'Californien',
      dateNaissance: iso(jMoins(75)),
      poids: 2.4,
      pereId: pere2,
      mereId: mere2,
      cageId: cageB[1],
      statut: 'engraissement',
    ));
    final engr2 = await lapinsRepo.insertLapin(Lapin(
      numeroBague: 'TEST-LP-014',
      sexe: 'femelle',
      race: 'Californienne',
      dateNaissance: iso(jMoins(73)),
      poids: 2.3,
      pereId: pere2,
      mereId: mere2,
      cageId: cageB[1],
      statut: 'engraissement',
    ));
    final engr3 = await lapinsRepo.insertLapin(Lapin(
      numeroBague: 'TEST-LP-015',
      sexe: 'male',
      race: 'Néo-Zélandais',
      dateNaissance: iso(jMoins(70)),
      poids: 2.2,
      pereId: pere1,
      mereId: mere3,
      cageId: cageB[1],
      statut: 'engraissement',
    ));

    // ── Lapereaux récents (fenêtre de sexage ~60 j) ──
    for (var i = 16; i <= 18; i++) {
      await lapinsRepo.insertLapin(Lapin(
        numeroBague: 'TEST-LP-${i.toString().padLeft(3, '0')}',
        sexe: i.isEven ? 'femelle' : 'male',
        race: 'Fauve de Bourgogne',
        dateNaissance: iso(jMoins(58)),
        poids: 1.3 + (i - 16) * 0.05,
        pereId: pere1,
        mereId: mere3,
        cageId: cageB[2],
        statut: 'actif',
      ));
    }

    // ── Reproducteur sélectionné (destination) ──
    await lapinsRepo.insertLapin(Lapin(
      numeroBague: 'TEST-LP-019',
      nom: 'Hermès',
      sexe: 'male',
      race: 'Néo-Zélandais',
      dateNaissance: iso(jMoins(230)),
      poids: 3.8,
      pereId: pere1,
      mereId: mere1,
      cageId: cageA[0],
      statut: 'actif',
      destination: 'reproducteur',
      notes: 'Sélectionné comme futur reproducteur (croissance exemplaire)',
    ));

    // ── Lapin vendu ──
    await lapinsRepo.insertLapin(Lapin(
      numeroBague: 'TEST-LP-020',
      sexe: 'male',
      race: 'Néo-Zélandais',
      dateNaissance: iso(jMoins(135)),
      poids: 2.5,
      pereId: pere1,
      mereId: mere1,
      statut: 'vendu',
      destination: 'vendu',
    ));

    // ── Lapin auto-consommé ──
    await lapinsRepo.insertLapin(Lapin(
      numeroBague: 'TEST-LP-021',
      sexe: 'femelle',
      race: 'Californienne',
      dateNaissance: iso(jMoins(128)),
      poids: 2.4,
      pereId: pere2,
      mereId: mere2,
      statut: 'vendu',
      destination: 'consomme',
    ));

    // ── Mortalité (2 cas, causes différentes) ──
    await lapinsRepo.insertLapin(Lapin(
      numeroBague: 'TEST-LP-022',
      sexe: 'male',
      dateNaissance: iso(jMoins(48)),
      poids: 0.9,
      pereId: pere1,
      mereId: mere1,
      statut: 'mort',
      causeMortalite: 'coccidiose',
      notes: 'Décès post-sevrage — diarrhée',
    ));
    await lapinsRepo.insertLapin(Lapin(
      numeroBague: 'TEST-LP-023',
      sexe: 'femelle',
      race: 'Rex',
      dateNaissance: iso(jMoins(260)),
      poids: 3.2,
      statut: 'mort',
      causeMortalite: 'coup_chaleur',
      notes: 'Décès lors de la vague de chaleur',
    ));

    // ══════════════════════════════════════════════════════════
    // 3. SAILLIES (6 — tous les stades du cycle)
    // ══════════════════════════════════════════════════════════
    // a) En attente — palpation à venir
    await sailliesRepo.insertSaillie(Saillie(
      mereId: mere1,
      pereId: pere1,
      dateSaillie: iso(jMoins(6)),
      dateMiseBasPrevue: iso(jMoins(6).add(const Duration(days: 31))),
      statut: 'en_attente',
      palpationPositive: false,
      nbChevauchements: 3,
    ));
    // b) Palpation négative — retour en saillie nécessaire
    await sailliesRepo.insertSaillie(Saillie(
      mereId: mere2,
      pereId: pere2,
      dateSaillie: iso(jMoins(18)),
      dateMiseBasPrevue: iso(jMoins(18).add(const Duration(days: 31))),
      statut: 'echec',
      palpationPositive: false,
      nbChevauchements: 1,
      notes: 'Palpation J+12 négative — à re-saillir',
    ));
    // c) Mise bas faite récemment → lot auto-créé
    final saillieMiseBas = await sailliesRepo.insertSaillie(Saillie(
      mereId: mere3,
      pereId: pere1,
      dateSaillie: iso(jMoins(38)),
      dateMiseBasPrevue: iso(jMoins(38).add(const Duration(days: 31))),
      dateMiseBasReelle: iso(jMoins(7)),
      nbNes: 9,
      nbVivants: 8,
      nbMorts: 1,
      statut: 'mise_bas',
      palpationPositive: true,
      nbChevauchements: 2,
      etatNid: 'Nid prêt — poils arrachés J+27',
    ));
    // d) Saillie terminée (sevrée)
    await sailliesRepo.insertSaillie(Saillie(
      mereId: mere1,
      pereId: pere1,
      dateSaillie: iso(jMoins(120)),
      dateMiseBasPrevue: iso(jMoins(120).add(const Duration(days: 31))),
      dateMiseBasReelle: iso(jMoins(88)),
      nbNes: 10,
      nbVivants: 9,
      nbMorts: 1,
      nbSevres: 8,
      dateSevrage: iso(jMoins(53)),
      poidsSevrageTotal: 6.4,
      statut: 'termine',
      palpationPositive: true,
    ));
    // e) Échec — avortement
    await sailliesRepo.insertSaillie(Saillie(
      mereId: mere2,
      pereId: pere1,
      dateSaillie: iso(jMoins(70)),
      dateMiseBasPrevue: iso(jMoins(70).add(const Duration(days: 31))),
      statut: 'echec',
      palpationPositive: true,
      notes: 'Gestation interrompue — pas de mise bas',
    ));
    // f) Mise bas plus ancienne (pour stats)
    await sailliesRepo.insertSaillie(Saillie(
      mereId: mere3,
      pereId: pere2,
      dateSaillie: iso(jMoins(150)),
      dateMiseBasPrevue: iso(jMoins(150).add(const Duration(days: 31))),
      dateMiseBasReelle: iso(jMoins(119)),
      nbNes: 7,
      nbVivants: 7,
      nbMorts: 0,
      nbSevres: 7,
      dateSevrage: iso(jMoins(84)),
      poidsSevrageTotal: 5.9,
      statut: 'termine',
      palpationPositive: true,
    ));

    // ══════════════════════════════════════════════════════════
    // 4. LOTS D'ENGRAISSEMENT + pesées + distributions
    // ══════════════════════════════════════════════════════════
    // Lot auto-créé depuis la mise bas récente
    final lotMiseBas = await lotsRepo.insertLot(Lot(
      code: 'TEST-LT-${today.year}-001',
      dateCreation: iso(jMoins(7)),
      cage: 'B1',
      nombreInitial: 8,
      saillieId: saillieMiseBas,
      notes: 'Lot auto-créé depuis la mise bas (test)',
    ));
    await dbInstance.update('saillies', {'lot_id': lotMiseBas},
        where: 'id = ?', whereArgs: [saillieMiseBas]);

    // Lot d'engraissement en cours (manuel) — avec suivi complet
    final lotEngr = await lotsRepo.insertLot(Lot(
      code: 'TEST-LT-${today.year}-002',
      dateCreation: iso(jMoins(45)),
      cage: 'B2',
      nombreInitial: 10,
      poidsInitial: 8.5,
      notes: 'Lot engraissement — suivi pesées + aliment',
    ));
    // Pesées du lot (croissance)
    await lotsRepo.insertPesee(Pesee(
      lotId: lotEngr,
      datePesee: iso(jMoins(31)),
      poidsTotal: 14.0,
      nombre: 10,
    ));
    await lotsRepo.insertPesee(Pesee(
      lotId: lotEngr,
      datePesee: iso(jMoins(17)),
      poidsTotal: 21.5,
      nombre: 10,
    ));
    await lotsRepo.insertPesee(Pesee(
      lotId: lotEngr,
      datePesee: iso(jMoins(3)),
      poidsTotal: 27.0,
      nombre: 10,
      notes: 'Proche du poids d\'abattage',
    ));
    // Distributions d'aliment sur le lot
    for (final j in [38, 31, 24, 17, 10, 3]) {
      await lotsRepo.insertDistribution(DistributionAliment(
        lotId: lotEngr,
        dateDistribution: iso(jMoins(j)),
        quantiteKg: 7.5,
        notes: 'Granulés croissance',
      ));
    }

    // Lot terminé (historique)
    await lotsRepo.insertLot(Lot(
      code: 'TEST-LT-${today.year}-OLD',
      dateCreation: iso(jMoins(120)),
      cage: 'B3',
      nombreInitial: 9,
      poidsInitial: 7.2,
      statut: 'termine',
      notes: 'Lot clôturé — vendu en gros',
    ));

    // ══════════════════════════════════════════════════════════
    // 5. SOINS — vaccinations, traitements, délai d'attente
    // ══════════════════════════════════════════════════════════
    // Vaccination VHD collective (tout l'élevage)
    await soinsRepo.insertSoin(Soin(
      lapinId: null,
      typeSoin: 'Vaccination VHD',
      dateSoin: iso(jMoins(60)),
      dateRappel: iso(jPlus(120)),
      produit: 'Filavac VHD K C+V',
      dose: '0,5 ml / sujet',
      veterinaire: 'Dr. Eyenga',
      cout: 9000,
      notes: 'Campagne semestrielle — cheptel complet',
    ));
    // Vaccination Myxomatose collective avec rappel proche (alerte)
    await soinsRepo.insertSoin(Soin(
      lapinId: null,
      typeSoin: 'Vaccination Myxomatose',
      dateSoin: iso(jMoins(165)),
      dateRappel: iso(jPlus(5)),
      produit: 'Mixohipra-FSA',
      dose: '0,5 ml / sujet',
      veterinaire: 'Dr. Eyenga',
      cout: 7500,
      notes: 'Rappel à programmer cette semaine',
    ));
    // Vermifuge collectif
    await soinsRepo.insertSoin(Soin(
      lapinId: null,
      typeSoin: 'Vermifuge',
      dateSoin: iso(jMoins(25)),
      produit: 'Panacur 2,5 %',
      dose: 'Eau de boisson 3 j',
      cout: 3500,
    ));
    // Antibiotique sur un lapin précis — DÉLAI D'ATTENTE ACTIF
    // (dateSoin récente + délai 28 j → vente bloquée → testable)
    await soinsRepo.insertSoin(Soin(
      lapinId: engr1,
      typeSoin: 'Antibiotique',
      dateSoin: iso(jMoins(4)),
      produit: 'Oxytétracycline',
      dose: '1 ml / 10 kg',
      veterinaire: 'Dr. Eyenga',
      cout: 2500,
      delaiAttenteJours: 28,
      notes: 'Coryza — délai d\'attente avant abattage 28 j',
    ));
    // Traitement coccidiose (lot)
    await soinsRepo.insertSoin(Soin(
      lapinId: null,
      typeSoin: 'Anticoccidien',
      dateSoin: iso(jMoins(40)),
      produit: 'Baycox 2,5 %',
      dose: 'Eau de boisson 2 j',
      cout: 4000,
      delaiAttenteJours: 0,
    ));
    // Soin individuel — plaie
    await soinsRepo.insertSoin(Soin(
      lapinId: pere2,
      typeSoin: 'Traitement plaie',
      dateSoin: iso(jMoins(15)),
      produit: 'Bétadine + cicatrisant',
      cout: 1000,
      notes: 'Petite blessure à la patte — désinfection',
    ));
    // Vaccination VHD individuelle (nouveau reproducteur en quarantaine)
    await soinsRepo.insertSoin(Soin(
      lapinId: engr2,
      typeSoin: 'Vaccination VHD',
      dateSoin: iso(jMoins(2)),
      dateRappel: iso(jPlus(180)),
      produit: 'Filavac VHD K C+V',
      dose: '0,5 ml',
      cout: 500,
    ));
    // Pesée sanitaire / contrôle parasitaire à venir (rappel)
    await soinsRepo.insertSoin(Soin(
      lapinId: null,
      typeSoin: 'Contrôle sanitaire',
      dateSoin: iso(jMoins(10)),
      dateRappel: iso(jPlus(20)),
      notes: 'Inspection visuelle gale des oreilles',
    ));

    // ══════════════════════════════════════════════════════════
    // 6. PESÉES INDIVIDUELLES — courbes de croissance
    // ══════════════════════════════════════════════════════════
    for (final entry in <int, List<List<num>>>{
      // lapinId : [ [joursAvant, poidsKg], ... ]
      engr1: [
        [60, 0.95], [45, 1.5], [30, 2.0], [15, 2.3], [2, 2.5],
      ],
      engr2: [
        [58, 0.9], [44, 1.4], [29, 1.9], [14, 2.2], [1, 2.4],
      ],
      engr3: [
        [55, 0.85], [40, 1.35], [25, 1.85], [10, 2.15],
      ],
    }.entries) {
      for (final p in entry.value) {
        await peseesRepo.insert(PeseeLapin(
          lapinId: entry.key,
          datePesee: iso(jMoins(p[0].toInt())),
          poids: p[1].toDouble(),
        ));
      }
    }

    // ══════════════════════════════════════════════════════════
    // 7. TÂCHES DE ROUTINE
    // ══════════════════════════════════════════════════════════
    await routinesRepo.insertTache(Tache(
      titre: 'Distribution des granulés',
      description: 'Nourrir tous les clapiers — ration du matin',
      categorie: 'nourriture',
      priorite: 'critique',
      recurrence: 'quotidien',
      heureRappel: '07:00',
    ));
    await routinesRepo.insertTache(Tache(
      titre: 'Remplir les abreuvoirs',
      categorie: 'eau',
      priorite: 'critique',
      recurrence: 'quotidien',
      heureRappel: '07:30',
    ));
    await routinesRepo.insertTache(Tache(
      titre: 'Ration du soir + observation',
      description: 'Nourrir et vérifier l\'état général du cheptel',
      categorie: 'observation',
      priorite: 'important',
      recurrence: 'quotidien',
      heureRappel: '17:30',
    ));
    await routinesRepo.insertTache(Tache(
      titre: 'Nettoyage des cages',
      categorie: 'nettoyage',
      priorite: 'important',
      recurrence: 'hebdomadaire',
    ));
    await routinesRepo.insertTache(Tache(
      titre: 'Désinfection complète des clapiers',
      categorie: 'nettoyage',
      priorite: 'normal',
      recurrence: 'mensuel',
    ));
    await routinesRepo.insertTache(Tache(
      titre: 'Vérifier les nids des femelles gestantes',
      categorie: 'reproduction',
      priorite: 'important',
      recurrence: 'quotidien',
      heureRappel: '08:00',
    ));
    await routinesRepo.insertTache(Tache(
      titre: 'Commander un sac de granulés',
      description: 'Stock granulés bientôt sous le seuil',
      categorie: 'custom',
      priorite: 'important',
      recurrence: 'ponctuel',
      dateEcheance: iso(jPlus(4)),
    ));

    // ══════════════════════════════════════════════════════════
    // 8. VENTES (6 — types et acheteurs variés)
    // ══════════════════════════════════════════════════════════
    final ventes = <Vente>[
      Vente(
        lapinId: null,
        dateVente: iso(jMoins(80)),
        typeVente: 'poids_vif',
        acheteur: 'Boucher Mbarga',
        prixVente: 27000,
        poids: 18.0,
        quantite: 8,
        notes: 'Lot complet vendu en gros',
      ),
      Vente(
        lapinId: null,
        dateVente: iso(jMoins(30)),
        typeVente: 'carcasse',
        acheteur: 'Restaurant Le Lapin d\'Or',
        prixVente: 18000,
        poids: 7.2,
        quantite: 3,
      ),
      Vente(
        lapinId: null,
        dateVente: iso(jMoins(15)),
        typeVente: 'poids_vif',
        acheteur: 'Marché Mokolo',
        prixVente: 13500,
        poids: 9.0,
        quantite: 4,
      ),
      Vente(
        lapinId: null,
        dateVente: iso(jMoins(7)),
        typeVente: 'vif',
        acheteur: 'Éleveur débutant (reproducteur)',
        prixVente: 20000,
        quantite: 1,
        notes: 'Jeune mâle vendu pour la reproduction',
      ),
      Vente(
        lapinId: null,
        dateVente: iso(jMoins(3)),
        typeVente: 'carcasse',
        acheteur: 'Particulier — Mme Atangana',
        prixVente: 6000,
        poids: 2.4,
        quantite: 1,
      ),
      Vente(
        lapinId: null,
        dateVente: iso(jMoins(1)),
        typeVente: 'poids_vif',
        acheteur: 'Boucher Mbarga',
        prixVente: 10000,
        poids: 6.5,
        quantite: 3,
      ),
    ];
    for (final v in ventes) {
      await dbInstance.insert('ventes', v.toMap());
    }

    // ══════════════════════════════════════════════════════════
    // 9. DÉPENSES (8 — catégories variées)
    // ══════════════════════════════════════════════════════════
    final depenses = <Map<String, dynamic>>[
      {'d': 90, 'c': 'aliment', 'm': 30000.0, 'desc': '2 sacs granulés 50 kg'},
      {'d': 60, 'c': 'soins', 'm': 9000.0, 'desc': 'Vaccins VHD — campagne'},
      {'d': 45, 'c': 'materiel', 'm': 35000.0, 'desc': '4 cages grillagées'},
      {'d': 30, 'c': 'aliment', 'm': 15000.0, 'desc': 'Sac granulés 50 kg'},
      {'d': 20, 'c': 'eau_electricite', 'm': 6000.0, 'desc': 'Facture eau du mois'},
      {'d': 15, 'c': 'soins', 'm': 7500.0, 'desc': 'Vaccin Myxomatose'},
      {'d': 8, 'c': 'transport', 'm': 4000.0, 'desc': 'Transport au marché'},
      {'d': 2, 'c': 'aliment', 'm': 5000.0, 'desc': 'Foin + paille'},
    ];
    for (final d in depenses) {
      await dbInstance.insert('depenses', Depense(
        dateDepense: iso(jMoins(d['d'] as int)),
        categorie: d['c'] as String,
        montant: d['m'] as double,
        description: d['desc'] as String,
        dateCreation: iso(today),
      ).toMap());
    }

    // ══════════════════════════════════════════════════════════
    // 10. STOCKS (6 — dont un sous le seuil + un périmé)
    // ══════════════════════════════════════════════════════════
    final stocks = <Stock>[
      // Sous le seuil → alerte stock critique
      Stock(
        produit: 'Granulés croissance',
        typeAliment: 'granules',
        quantite: 38,
        unite: 'kg',
        quantiteMin: 50,
        dateEntree: iso(jMoins(25)),
        coutUnitaire: 320,
        fournisseur: 'Provende du Centre',
      ),
      Stock(
        produit: 'Granulés reproduction',
        typeAliment: 'granules',
        quantite: 70,
        unite: 'kg',
        quantiteMin: 30,
        dateEntree: iso(jMoins(20)),
        coutUnitaire: 350,
      ),
      Stock(
        produit: 'Foin de brousse',
        typeAliment: 'foin',
        quantite: 90,
        unite: 'kg',
        quantiteMin: 20,
        dateEntree: iso(jMoins(15)),
      ),
      Stock(
        produit: 'Paille (litière)',
        typeAliment: 'paille',
        quantite: 60,
        unite: 'kg',
        quantiteMin: 15,
        dateEntree: iso(jMoins(15)),
      ),
      // Proche de la péremption → alerte
      Stock(
        produit: 'Anticoccidien Baycox',
        typeAliment: 'medicament',
        quantite: 1,
        unite: 'flacon',
        quantiteMin: 1,
        dateEntree: iso(jMoins(120)),
        dateExpiration: iso(jPlus(12)),
        coutUnitaire: 4000,
        notes: 'À utiliser avant péremption',
      ),
      Stock(
        produit: 'Complément vitaminé',
        typeAliment: 'complement',
        quantite: 3,
        unite: 'sachet',
        quantiteMin: 1,
        dateEntree: iso(jMoins(40)),
        coutUnitaire: 1500,
      ),
    ];
    for (final s in stocks) {
      await dbInstance.insert('stocks', s.toMap());
    }

    return '✅ Données de test insérées :\n'
        '• 24 lapins (tous statuts, destinations, mortalité)\n'
        '• 1 bâtiment, 3 clapiers, 12 cages\n'
        '• 6 saillies (attente / échec / mise bas / terminée)\n'
        '• 8 soins (vaccins, vermifuge, délai d\'attente actif)\n'
        '• Pesées de croissance pour 3 lapereaux\n'
        '• 3 lots + pesées + distributions d\'aliment\n'
        '• 7 tâches de routine\n'
        '• 6 ventes, 8 dépenses, 6 stocks';
  }
}
