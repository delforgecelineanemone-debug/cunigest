// ──────────────────────────────────────────────────────────────
// LapinDetailNotifier — données de la fiche détaillée d'un lapin (P1.8)
// ──────────────────────────────────────────────────────────────
// Charge en 2 vagues parallèles tout l'état d'un lapin :
//   - le lapin frais, ses soins, son délai d'attente actif
//   - sa chaîne cage → clapier → bâtiment
//   - ses parents (père / mère)
//   - ses mouvements de cage, pesées, saillies
//   - ses totaux financiers (dépenses + ventes imputées)
//
// Family paramétré par `lapinId`. Réactif via DataBus : toute écriture
// touchant ce lapin (pesée, soin, mouvement, saillie…) rafraîchit.
//
// La CONSTRUCTION de la timeline reste côté widget — c'est de la
// présentation pure (couleurs, icônes), pas de la donnée.
// ──────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/db_helper.dart';
import '../models/batiment.dart';
import '../models/cage.dart';
import '../models/clapier.dart';
import '../models/lapin.dart';
import '../models/mouvement_cage.dart';
import '../models/pesee_lapin.dart';
import '../models/saillie.dart';
import '../models/soin.dart';
import '../services/data_bus.dart';

class LapinDetailData {
  final Lapin lapin;
  final List<Soin> soins;
  final Lapin? pere;
  final Lapin? mere;
  final Soin? delaiActif;
  final Cage? cage;
  final Clapier? clapier;
  final Batiment? batiment;
  final List<MouvementCage> mvts;
  final List<PeseeLapin> pesees;
  final List<Saillie> saillies;
  final double depensesLapin;
  final double ventesLapin;

  const LapinDetailData({
    required this.lapin,
    required this.soins,
    this.pere,
    this.mere,
    this.delaiActif,
    this.cage,
    this.clapier,
    this.batiment,
    required this.mvts,
    required this.pesees,
    required this.saillies,
    required this.depensesLapin,
    required this.ventesLapin,
  });
}

class LapinDetailNotifier
    extends FamilyAsyncNotifier<LapinDetailData, int> {
  late int _lapinId;
  StreamSubscription<String>? _sub;
  Timer? _debounce;

  @override
  Future<LapinDetailData> build(int arg) async {
    _lapinId = arg;
    _sub?.cancel();
    _sub = DataBus.instance.subscribe(
      const [
        DataTopics.lapins,
        DataTopics.soins,
        DataTopics.peseesLapin,
        DataTopics.mouvementsCage,
        DataTopics.saillies,
        DataTopics.cages,
        DataTopics.ventes,
        DataTopics.depenses,
      ],
      (_) => _scheduleRefresh(),
    );
    ref.onDispose(() {
      _sub?.cancel();
      _debounce?.cancel();
    });
    return _load();
  }

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 80), refresh);
  }

  Future<LapinDetailData> _load() async {
    final db = DBHelper.instance;
    final id = _lapinId;
    final (lapinsRepo, soinsRepo, sailliesRepo) =
        await (db.lapins, db.soins, db.saillies).wait;

    // Vague 1 — indépendant du contenu du lapin
    final (fresh, soins, delai, cagesRepo, peseesRepo, depRepo, venteRepo) =
        await (
      lapinsRepo.getLapinById(id),
      soinsRepo.getSoinsByLapin(id),
      soinsRepo.getSoinDelaiAttenteActif(id),
      db.cages,
      db.peseesLapin,
      db.depenses,
      db.ventes,
    ).wait;

    if (fresh == null) {
      throw StateError('Lapin #$id introuvable (supprimé ?).');
    }

    // Vague 2 — chaîne cage (séquentielle interne) + le reste en parallèle
    Future<(Cage?, Clapier?, Batiment?)> cageChain() async {
      if (fresh.cageId == null) return (null, null, null);
      final cage = await cagesRepo.getCageById(fresh.cageId!);
      if (cage == null) return (null, null, null);
      final clapier = await cagesRepo.getClapierById(cage.clapierId);
      if (clapier == null) return (cage, null, null);
      final batiment = await cagesRepo.getBatimentById(clapier.batimentId);
      return (cage, clapier, batiment);
    }

    final (cageData, pere, mere, mvts, pesees, saillies, depTotal, venteTotal) =
        await (
      cageChain(),
      fresh.pereId != null
          ? lapinsRepo.getLapinById(fresh.pereId!)
          : Future<Lapin?>.value(null),
      fresh.mereId != null
          ? lapinsRepo.getLapinById(fresh.mereId!)
          : Future<Lapin?>.value(null),
      cagesRepo.getHistoriqueLapin(id),
      peseesRepo.getByLapin(id),
      fresh.sexe == 'femelle'
          ? sailliesRepo.getSailliesByMere(id)
          : sailliesRepo.getSailliesByPere(id),
      depRepo.totalParLapin(id),
      venteRepo.totalParLapin(id),
    ).wait;

    final (cage, clapier, batiment) = cageData;

    return LapinDetailData(
      lapin: fresh,
      soins: soins,
      pere: pere,
      mere: mere,
      delaiActif: delai,
      cage: cage,
      clapier: clapier,
      batiment: batiment,
      mvts: mvts,
      pesees: pesees,
      saillies: saillies,
      depensesLapin: depTotal,
      ventesLapin: venteTotal,
    );
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_load);
  }
}

final lapinDetailProvider = AsyncNotifierProvider.family<LapinDetailNotifier,
    LapinDetailData, int>(LapinDetailNotifier.new);
