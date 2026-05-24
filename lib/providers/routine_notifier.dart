// ──────────────────────────────────────────────────────────────
// RoutineNotifier — données de l'écran routine quotidienne (P1.8)
// ──────────────────────────────────────────────────────────────
// Charge en parallèle :
//   - tâches du jour
//   - complétions du jour
//   - profil éleveur (streak / niveau / score)
//   - badges obtenus
//
// Réactivité : abonné aux topics `taches`, `completions`, `profil`.
// Toute écriture (toggle tâche, mise à jour score, déblocage badge)
// rafraîchit automatiquement la vue.
// ──────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/db_helper.dart';
import '../models/profil.dart';
import '../models/tache.dart';
import '../services/data_bus.dart';
import '../services/notification_service.dart';

class RoutineData {
  final List<Tache> taches;
  final Set<int> completees;
  final ProfilEleveur profil;
  final List<BadgeEleveur> badges;
  final List<String> nouveauxBadges; // débloqués lors du dernier toggle

  const RoutineData({
    this.taches = const [],
    this.completees = const {},
    required this.profil,
    this.badges = const [],
    this.nouveauxBadges = const [],
  });

  int get scoreMax => taches.fold(0, (sum, t) => sum + t.points);
  int get scoreActuel =>
      taches.where((t) => completees.contains(t.id)).fold(0, (sum, t) => sum + t.points);
  double get progression =>
      scoreMax > 0 ? (scoreActuel / scoreMax).clamp(0.0, 1.0) : 0.0;
  int get nbCompletees =>
      taches.where((t) => completees.contains(t.id)).length;

  RoutineData copyWith({
    List<Tache>? taches,
    Set<int>? completees,
    ProfilEleveur? profil,
    List<BadgeEleveur>? badges,
    List<String>? nouveauxBadges,
  }) =>
      RoutineData(
        taches: taches ?? this.taches,
        completees: completees ?? this.completees,
        profil: profil ?? this.profil,
        badges: badges ?? this.badges,
        nouveauxBadges: nouveauxBadges ?? this.nouveauxBadges,
      );
}

class RoutineNotifier extends AsyncNotifier<RoutineData> {
  StreamSubscription<String>? _sub;
  Timer? _debounce;

  @override
  Future<RoutineData> build() async {
    _sub?.cancel();
    _sub = DataBus.instance.subscribe(
      const [DataTopics.taches, DataTopics.completions, DataTopics.profil],
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
    _debounce = Timer(const Duration(milliseconds: 60), refresh);
  }

  Future<RoutineData> _load() async {
    final db = DBHelper.instance;
    final (routinesRepo, profilRepo) = await (db.routines, db.profil).wait;
    final (taches, completees, profil, badges) = await (
      routinesRepo.getTachesDuJour(),
      routinesRepo.getTachesCompleteesAujourdhui(),
      profilRepo.getProfil(),
      profilRepo.getBadgesObtenus(),
    ).wait;
    return RoutineData(
      taches: taches,
      completees: completees,
      profil: profil,
      badges: badges,
    );
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_load);
  }

  /// Bascule l'état d'une tâche (complétée ↔ non complétée). Renvoie la
  /// liste des nouveaux badges débloqués (vide si rien). L'UI peut s'en
  /// servir pour afficher le popup félicitations.
  Future<List<String>> toggleTache(Tache t) async {
    final db = DBHelper.instance;
    final (routinesRepo, profilRepo) = await (db.routines, db.profil).wait;
    final current = state.value;
    final estFait = current?.completees.contains(t.id) ?? false;
    final List<String> nouveauxBadges;
    if (estFait) {
      await routinesRepo.deCompleterTache(t.id!);
      await profilRepo.mettreAJourScore(-t.points);
      nouveauxBadges = const [];
    } else {
      await routinesRepo.completerTache(t.id!);
      final profil = await profilRepo.mettreAJourScore(t.points);
      nouveauxBadges = await db.verifierBadges();
      for (final badge in nouveauxBadges) {
        await NotificationService.instance.envoyerFelicitation(
          '🏆 Nouveau Badge !',
          'Vous avez débloqué : $badge',
        );
      }
      await NotificationService.instance.rappelerStreak(profil.streakActuel);
    }
    // Refresh complet — le DataBus aurait déjà déclenché un refresh debounce
    // mais on le force pour avoir une donnée immédiate à retourner.
    await refresh();
    if (nouveauxBadges.isNotEmpty) {
      final current = state.value;
      if (current != null) {
        state = AsyncData(current.copyWith(nouveauxBadges: nouveauxBadges));
      }
    }
    return nouveauxBadges;
  }

  /// Ajoute une tâche personnalisée. Le DataBus rafraîchit la vue.
  Future<int> ajouterTache(Tache t) async {
    final repo = await DBHelper.instance.routines;
    return repo.insertTache(t);
  }

  /// Réinitialise les nouveaux badges après que l'UI les ait consommés.
  void acquitterNouveauxBadges() {
    final current = state.value;
    if (current == null || current.nouveauxBadges.isEmpty) return;
    state = AsyncData(current.copyWith(nouveauxBadges: const []));
  }
}

final routineProvider =
    AsyncNotifierProvider<RoutineNotifier, RoutineData>(RoutineNotifier.new);
