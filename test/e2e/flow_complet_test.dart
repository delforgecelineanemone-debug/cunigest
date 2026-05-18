// ──────────────────────────────────────────────────────────────
// Test end-to-end métier — Flux complet d'une portée CuniGest
// ──────────────────────────────────────────────────────────────
// Scénario : on suit le parcours réel d'un éleveur, du jour où il
// crée son compte jusqu'à la vente d'un lapereau issu d'une portée.
//
// Étapes :
//   1. Compte utilisateur (admin, PIN)
//   2. Lapine reproductrice (femelle, actif)
//   3. Mâle reproducteur (male, actif)
//   4. Saillie déclarée (date_mise_bas_prevue = saillie + 31 j)
//   5. Mise bas enregistrée (nb_nes >= nb_vivants)
//   6. Lot d'engraissement auto-lié à la saillie
//   7. Sevrage (nb_vivants >= nb_sevres)
//   8. Individualisation : 6 lapereaux baguer un par un
//   9. Vente d'un lapereau (statut → vendu)
//  10. Statistiques finales cohérentes
//
// Aucune dépendance UI, pas de Widget. Pur test d'intégration
// repos + base SQLite en mémoire (helpers/test_db.dart).
// ──────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/models/lapin.dart';
import 'package:gestion_cunicole/models/lot.dart';
import 'package:gestion_cunicole/models/saillie.dart';
import 'package:gestion_cunicole/models/vente.dart';
import 'package:gestion_cunicole/repositories/lapin_repository.dart';
import 'package:gestion_cunicole/repositories/lot_repository.dart';
import 'package:gestion_cunicole/repositories/saillie_repository.dart';
import 'package:gestion_cunicole/repositories/user_repository.dart';
import 'package:gestion_cunicole/repositories/vente_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

void main() {
  late Database db;

  setUp(() async {
    db = await openTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  test('flux complet : compte → reproducteurs → saillie → mise bas → '
      'lot → sevrage → individualisation → vente → stats', () async {
    // Instancie tous les repos sur la même base en mémoire.
    final users = UserRepository(db);
    final lapins = LapinRepository(db);
    final saillies = SaillieRepository(db);
    final lots = LotRepository(db);
    final ventes = VenteRepository(db);

    // ── ÉTAPE 1 : création du compte admin ──────────────────────
    // L'éleveur ouvre l'app la 1re fois et se crée un compte PIN.
    final userId = await users.create(
      nom: 'Yao',
      role: 'admin',
      pin: '1234',
    );
    expect(userId, isPositive,
        reason: 'le compte doit être créé en base');

    // PIN haché, jamais en clair.
    final connecte = await users.authenticate('Yao', '1234');
    expect(connecte, isNotNull, reason: 'PIN valide → authentification OK');
    expect(connecte!.role, 'admin');
    expect(connecte.pinHash, isNot('1234'),
        reason: 'le PIN ne doit JAMAIS être stocké en clair');

    final faux = await users.authenticate('Yao', '0000');
    expect(faux, isNull, reason: 'mauvais PIN → refus');

    // ── ÉTAPE 2 : lapine reproductrice ──────────────────────────
    // Femelle adulte achetée, statut actif.
    final mereId = await lapins.insertLapin(Lapin(
      numeroBague: 'F-001',
      nom: 'Bella',
      sexe: 'femelle',
      race: 'Néo-Zélandais',
      dateNaissance: '2025-08-01',
      statut: 'actif',
    ));
    expect(mereId, isPositive);
    final mere = await lapins.getLapinById(mereId);
    expect(mere!.sexe, 'femelle');
    expect(mere.statut, 'actif');

    // ── ÉTAPE 3 : mâle reproducteur ─────────────────────────────
    final pereId = await lapins.insertLapin(Lapin(
      numeroBague: 'M-001',
      nom: 'Costaud',
      sexe: 'male',
      race: 'Californien',
      dateNaissance: '2025-07-15',
      statut: 'actif',
    ));
    expect(pereId, isPositive);
    final pere = await lapins.getLapinById(pereId);
    expect(pere!.sexe, 'male');

    // Vérif : on a bien 1 femelle et 1 mâle actifs.
    final statsCheptel0 = await lapins.getStatistiquesLapins();
    expect(statsCheptel0['femelles'], 1);
    expect(statsCheptel0['males'], 1);
    expect(statsCheptel0['actifs'], 2);

    // ── ÉTAPE 4 : saillie déclarée ──────────────────────────────
    // Gestation lapine = 31 jours. L'éleveur calcule la date prévue
    // de mise bas et la stocke (date_saillie + 31 j).
    const dateSaillie = '2026-04-01';
    final dateMiseBasPrevue = DateTime.parse(dateSaillie)
        .add(const Duration(days: 31))
        .toIso8601String()
        .substring(0, 10);
    expect(dateMiseBasPrevue, '2026-05-02',
        reason: 'avril a 30 jours → 1er avril + 31 j = 2 mai');

    final saillieId = await saillies.insertSaillie(Saillie(
      mereId: mereId,
      pereId: pereId,
      dateSaillie: dateSaillie,
      dateMiseBasPrevue: dateMiseBasPrevue,
      statut: 'en_attente',
      palpationPositive: true,
    ));
    expect(saillieId, isPositive);

    final saillieCreee =
        (await saillies.getSailliesByMere(mereId)).single;
    expect(saillieCreee.statut, 'en_attente');
    expect(saillieCreee.dateMiseBasPrevue, '2026-05-02');
    expect(saillieCreee.palpationPositive, isTrue);

    // ── ÉTAPE 5 : mise bas réelle ───────────────────────────────
    // 8 lapereaux nés au total, 1 mort-né → 7 vivants.
    // Règle métier : nb_nes >= nb_vivants.
    const nbNes = 8;
    const nbVivants = 7;
    expect(nbNes >= nbVivants, isTrue,
        reason: 'règle métier : on ne peut pas avoir plus de vivants '
            'que de nés');

    const dateMiseBasReelle = '2026-05-02';
    final miseBasOk = await saillies.updateSaillie(saillieCreee.copyWith(
      nbNes: nbNes,
      nbVivants: nbVivants,
      nbMorts: nbNes - nbVivants,
      dateMiseBasReelle: dateMiseBasReelle,
      statut: 'mise_bas',
    ));
    expect(miseBasOk, 1, reason: '1 ligne mise à jour');

    final apresMiseBas = (await saillies.getSailliesByMere(mereId)).single;
    expect(apresMiseBas.statut, 'mise_bas');
    expect(apresMiseBas.nbNes, 8);
    expect(apresMiseBas.nbVivants, 7);
    expect(apresMiseBas.nbMorts, 1);
    expect(apresMiseBas.dateMiseBasReelle, dateMiseBasReelle);

    // ── ÉTAPE 6 : lot d'engraissement lié à la saillie ──────────
    // Code lot unique (contrainte UNIQUE en base). Statut 'en_cours'.
    // nombreInitial = nb_vivants à la naissance (= 7).
    final lotId = await lots.insertLot(Lot(
      code: 'LT-2026-05-001',
      dateCreation: dateMiseBasReelle,
      nombreInitial: nbVivants,
      statut: 'en_cours',
      saillieId: saillieId,
    ));
    expect(lotId, isPositive);

    final lotCree = await lots.getById(lotId);
    expect(lotCree, isNotNull);
    expect(lotCree!.code, 'LT-2026-05-001');
    expect(lotCree.statut, 'en_cours');
    expect(lotCree.nombreInitial, 7,
        reason: 'lot démarre avec autant de lapereaux que vivants');
    expect(lotCree.saillieId, saillieId,
        reason: 'traçabilité saillie → lot pour calculer les perfs');

    // Code unique : un 2e lot avec même code doit échouer.
    await expectLater(
      lots.insertLot(Lot(
        code: 'LT-2026-05-001',
        dateCreation: dateMiseBasReelle,
        nombreInitial: 5,
      )),
      throwsA(isA<DatabaseException>()),
      reason: 'le code lot est unique',
    );

    // ── ÉTAPE 7 : sevrage (J+28) ────────────────────────────────
    // 1 lapereau perdu entre J0 et J28 → 6 sevrés sur 7 vivants.
    // Règle métier : nb_vivants >= nb_sevres.
    const nbSevres = 6;
    expect(nbVivants >= nbSevres, isTrue,
        reason: 'règle métier : on ne sèvre pas plus que de vivants');

    final dateSevrage = DateTime.parse(dateMiseBasReelle)
        .add(const Duration(days: 28))
        .toIso8601String()
        .substring(0, 10);
    expect(dateSevrage, '2026-05-30');

    await saillies.updateSaillie(apresMiseBas.copyWith(
      nbSevres: nbSevres,
      dateSevrage: dateSevrage,
      statut: 'sevrage',
    ));

    final apresSevrage = (await saillies.getSailliesByMere(mereId)).single;
    expect(apresSevrage.statut, 'sevrage');
    expect(apresSevrage.nbSevres, 6);
    expect(apresSevrage.dateSevrage, '2026-05-30');

    // Mortalité pré-sevrage calculée par le modèle (= (vivants-sevres)/vivants).
    final mortPct = apresSevrage.mortalitePreSevrage;
    expect(mortPct, isNotNull);
    expect(mortPct!, closeTo(14.28, 0.1),
        reason: '(7 - 6) / 7 ≈ 14,28 %');

    // ── ÉTAPE 8 : individualisation du lot ──────────────────────
    // À J+60, on sexe et bague chaque lapereau. Ici 6 lapereaux
    // issus de Bella × Costaud, on les enregistre individuellement
    // avec leur généalogie. On les ajoute aussi à `lot_lapins`.
    final lapereauIds = <int>[];
    for (var i = 1; i <= nbSevres; i++) {
      final id = await lapins.insertLapin(Lapin(
        numeroBague: 'L-2026-${i.toString().padLeft(3, '0')}',
        sexe: i.isEven ? 'femelle' : 'male',
        dateNaissance: dateMiseBasReelle,
        statut: 'actif',
        pereId: pereId,
        mereId: mereId,
      ));
      expect(id, isPositive);
      lapereauIds.add(id);
      // Le lapereau rejoint le lot d'engraissement.
      await lots.ajouterLapin(lotId, id, dateSevrage);
    }
    expect(lapereauIds.length, 6);

    // Passe le lot au statut 'individualise' (V13).
    await lots.update(lotCree.copyWith(statut: 'individualise'));
    final lotIndiv = await lots.getById(lotId);
    expect(lotIndiv!.statut, 'individualise');

    // Les 6 lapereaux sont bien rattachés au lot.
    final lapereauxDuLot = await lots.getLapinIdsDuLot(lotId);
    expect(lapereauxDuLot.length, 6);
    expect(lapereauxDuLot.toSet(), lapereauIds.toSet());

    // Généalogie : chaque lapereau pointe vers Bella et Costaud.
    final premier = await lapins.getLapinById(lapereauIds.first);
    expect(premier!.mereId, mereId);
    expect(premier.pereId, pereId);

    // ── ÉTAPE 9 : vente d'un lapereau ──────────────────────────
    // L'éleveur vend 1 lapereau vivant à 4 500 FCFA.
    final lapereauVenduId = lapereauIds.first;
    const prix = 4500.0;

    final venteId = await ventes.insertVente(Vente(
      lapinId: lapereauVenduId,
      dateVente: '2026-07-01',
      typeVente: 'lapereau',
      acheteur: 'Marché de Yopougon',
      prixVente: prix,
      poids: 2.3,
    ));
    expect(venteId, isPositive);

    // insertVente est transactionnel : le statut du lapin passe à 'vendu'.
    final lapereauVendu = await lapins.getLapinById(lapereauVenduId);
    expect(lapereauVendu!.statut, 'vendu',
        reason: 'la vente doit basculer automatiquement le statut');

    // La vente est bien rattachée au lapin avec le bon montant.
    final ventesDuLapin = await ventes.getByLapin(lapereauVenduId);
    expect(ventesDuLapin.length, 1);
    expect(ventesDuLapin.first.prixVente, prix);
    expect(ventesDuLapin.first.acheteur, 'Marché de Yopougon');
    expect(ventesDuLapin.first.typeVente, 'lapereau');

    // ── ÉTAPE 10 : statistiques finales ────────────────────────
    // a) Bella a 1 portée à son actif (statut sevrage = portée comptée).
    final sailliesDeBella = await saillies.getSailliesByMere(mereId);
    expect(sailliesDeBella.length, 1);
    expect(sailliesDeBella.first.statut, 'sevrage');
    expect(await saillies.countTerminees(), 1,
        reason: 'mise_bas/sevrage/termine sont comptées comme portées');

    // b) Stats reproduction globales : mortalité pré-sevrage ≈ 14 %.
    final statsRepro = await saillies.getStatistiquesReproduction();
    expect(statsRepro['nombre_saillies'], 1);
    expect(statsRepro['nombre_positives'], 1);
    expect(statsRepro['nombre_echecs'], 0);
    expect(statsRepro['total_nes_vivants'], 7);
    expect(statsRepro['total_sevres'], 6);
    expect(
      statsRepro['taux_mortalite_pre_sevrage_pct'] as double,
      closeTo(14.28, 0.1),
      reason: '(7 - 6) / 7 ≈ 14,28 %',
    );
    expect(
      statsRepro['prolificite_moyenne'] as double,
      closeTo(7.0, 0.001),
      reason: 'moyenne de nb_vivants sur 1 portée = 7',
    );

    // c) 1 vente enregistrée, montant cohérent.
    final statsVentes = await ventes.getStatistiquesVentes();
    expect(statsVentes['nombre_total'], 1);
    expect(statsVentes['chiffre_affaires_total'], prix);
    expect(await ventes.totalParLapin(lapereauVenduId), prix);

    // d) Cheptel après vente : 1 femelle adulte (Bella) + 1 mâle
    //    adulte (Costaud) + 5 lapereaux actifs + 1 vendu = 7 lapins
    //    au total dont 6 encore actifs.
    final statsCheptelFinal = await lapins.getStatistiquesLapins();
    expect(statsCheptelFinal['total'], 8,
        reason: '2 reproducteurs + 6 lapereaux individualisés');
    expect(statsCheptelFinal['actifs'], 7,
        reason: '8 - 1 vendu = 7 actifs');
  });
}
