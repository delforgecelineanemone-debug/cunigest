// ──────────────────────────────────────────────────────────────
// State Providers — Riverpod NotifierProvider (V2.5 — P1.7)
// ──────────────────────────────────────────────────────────────
// Tous les états globaux de l'app sont gérés via Riverpod Notifier.
// Plus aucun ChangeNotifier brut : un seul pattern, testable, prévisible.
//
// Convention :
//   - View-state immuable (suffix `ViewState`) avec getters dérivés.
//   - Notifier exposant des mutations explicites + refresh().
//   - Chaque notifier s'abonne au DataBus pour rester réactif aux
//     écritures locales ET aux pulls cloud (multi-device).
//
// Usage écran (inchangé depuis V2.4) :
//   final reglages = ref.watch(reglagesProvider).reglages;
//   await ref.read(reglagesProvider.notifier).refresh();
// ──────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/db_helper.dart';
import '../models/lapin.dart';
import '../models/profil.dart';
import '../models/reglages.dart';
import '../models/user.dart';
import '../services/auth/session_manager.dart';
import '../services/data_bus.dart';
import '../services/image_service.dart';
import '../utils/theme.dart';

// ══════════════════════════════════════════════════════════════
// SESSION — utilisateur courant + permissions
// ══════════════════════════════════════════════════════════════

class SessionViewState {
  final AppUser? currentUser;

  const SessionViewState({this.currentUser});

  bool get isAuthenticated => currentUser != null;
  bool get isAdmin => currentUser?.role == 'admin';
  bool get peutVoirFinances => currentUser?.peutVoirFinances ?? true;
  bool get peutSupprimer => currentUser?.peutSupprimer ?? true;
  bool get peutModifierReglages => currentUser?.peutModifierReglages ?? true;
}

class SessionNotifier extends Notifier<SessionViewState> {
  @override
  SessionViewState build() => const SessionViewState();

  void login(AppUser user) {
    state = SessionViewState(currentUser: user);
  }

  void logout() {
    state = const SessionViewState();
  }

  /// Mode "solo legacy" : pas d'utilisateur défini (DB sans table users
  /// peuplée) → tout est autorisé comme en V1.
  void setSoloLegacy() {
    state = const SessionViewState();
  }
}

final sessionProvider =
    NotifierProvider<SessionNotifier, SessionViewState>(SessionNotifier.new);

// ══════════════════════════════════════════════════════════════
// LAPINS — liste + filtres + recherche, auto-réactif via DataBus
// ══════════════════════════════════════════════════════════════

class LapinsViewState {
  final List<Lapin> all;
  final String search;
  final String filtreStatut;
  final bool loading;

  const LapinsViewState({
    this.all = const [],
    this.search = '',
    this.filtreStatut = 'tous',
    this.loading = false,
  });

  LapinsViewState copyWith({
    List<Lapin>? all,
    String? search,
    String? filtreStatut,
    bool? loading,
  }) =>
      LapinsViewState(
        all: all ?? this.all,
        search: search ?? this.search,
        filtreStatut: filtreStatut ?? this.filtreStatut,
        loading: loading ?? this.loading,
      );

  /// Lapins filtrés selon recherche + statut.
  List<Lapin> get filtered {
    final q = search.toLowerCase();
    return all.where((l) {
      final matchSearch = q.isEmpty ||
          l.numeroBague.toLowerCase().contains(q) ||
          (l.nom?.toLowerCase().contains(q) ?? false);
      final matchStatut = filtreStatut == 'tous' || l.statut == filtreStatut;
      return matchSearch && matchStatut;
    }).toList();
  }

  Map<int, Lapin> get byId =>
      {for (var l in all) if (l.id != null) l.id!: l};

  int get nbActifs => all.where((l) => l.statut == 'actif').length;
  int get nbMales =>
      all.where((l) => l.sexe == 'male' && l.statut == 'actif').length;
  int get nbFemelles =>
      all.where((l) => l.sexe == 'femelle' && l.statut == 'actif').length;
}

class LapinsNotifier extends Notifier<LapinsViewState> {
  final _db = DBHelper.instance;
  bool _refreshing = false;

  @override
  LapinsViewState build() {
    final sub = DataBus.instance
        .subscribe([DataTopics.lapins], (_) => refresh());
    ref.onDispose(sub.cancel);
    // Premier chargement asynchrone — état initial vide affiché immédiatement.
    Future.microtask(refresh);
    return const LapinsViewState(loading: true);
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      if (!state.loading) {
        state = state.copyWith(loading: true);
      }
      final rows = await (await _db.lapins).getAllLapins();
      state = state.copyWith(all: rows, loading: false);
    } finally {
      _refreshing = false;
    }
  }

  void setSearch(String s) {
    if (s == state.search) return;
    state = state.copyWith(search: s);
  }

  void setFiltreStatut(String s) {
    if (s == state.filtreStatut) return;
    state = state.copyWith(filtreStatut: s);
  }

  /// Insère un nouveau lapin. Le DataBus se charge du refresh.
  Future<int> ajouter(Lapin l) async => (await _db.lapins).insertLapin(l);

  Future<int> modifier(Lapin l) async => (await _db.lapins).updateLapin(l);

  Future<int> supprimer(int id) async {
    final photoPath = state.all.where((l) => l.id == id).firstOrNull?.photoPath;
    final r = await (await _db.lapins).deleteLapin(id);
    if (photoPath != null) await ImageService.deletePhoto(photoPath);
    return r;
  }
}

final lapinsProvider =
    NotifierProvider<LapinsNotifier, LapinsViewState>(LapinsNotifier.new);

// ══════════════════════════════════════════════════════════════
// PROFIL — gamification (streak, niveau, score)
// ══════════════════════════════════════════════════════════════

class ProfilViewState {
  final ProfilEleveur profil;
  final bool loading;

  ProfilViewState({
    ProfilEleveur? profil,
    this.loading = false,
  }) : profil = profil ?? ProfilEleveur();

  int get streak => profil.streakActuel;
  int get niveau => profil.niveau;

  ProfilViewState copyWith({ProfilEleveur? profil, bool? loading}) =>
      ProfilViewState(
        profil: profil ?? this.profil,
        loading: loading ?? this.loading,
      );
}

class ProfilNotifier extends Notifier<ProfilViewState> {
  final _db = DBHelper.instance;
  bool _refreshing = false;

  @override
  ProfilViewState build() {
    final sub = DataBus.instance.subscribe(
      const [DataTopics.profil, DataTopics.completions],
      (_) => refresh(),
    );
    ref.onDispose(sub.cancel);
    Future.microtask(refresh);
    return ProfilViewState(loading: true);
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      if (!state.loading) state = state.copyWith(loading: true);
      final p = await (await _db.profil).getProfil();
      state = state.copyWith(profil: p, loading: false);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> completerTache(int tacheId, int points) async {
    await (await _db.routines).completerTache(tacheId);
    final updated = await (await _db.profil).mettreAJourScore(points);
    state = state.copyWith(profil: updated);
  }

  Future<void> deCompleterTache(int tacheId, int points) async {
    await (await _db.routines).deCompleterTache(tacheId);
    final updated = await (await _db.profil).mettreAJourScore(-points);
    state = state.copyWith(profil: updated);
  }
}

final profilProvider =
    NotifierProvider<ProfilNotifier, ProfilViewState>(ProfilNotifier.new);

// ══════════════════════════════════════════════════════════════
// RÉGLAGES — préférences app (thème, gamif, devise, modes terrain)
// ══════════════════════════════════════════════════════════════

class ReglagesViewState {
  final Reglages reglages;
  final bool loading;

  const ReglagesViewState({
    this.reglages = const Reglages(),
    this.loading = false,
  });

  bool get gamificationActive => reglages.gamificationActive;
  bool get notificationsActives => reglages.notificationsActives;

  ReglagesViewState copyWith({Reglages? reglages, bool? loading}) =>
      ReglagesViewState(
        reglages: reglages ?? this.reglages,
        loading: loading ?? this.loading,
      );
}

class ReglagesNotifier extends Notifier<ReglagesViewState> {
  final _db = DBHelper.instance;
  bool _refreshing = false;

  @override
  ReglagesViewState build() {
    final sub = DataBus.instance
        .subscribe([DataTopics.reglages], (_) => refresh());
    ref.onDispose(sub.cancel);
    Future.microtask(refresh);
    return const ReglagesViewState(loading: true);
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      if (!state.loading) state = state.copyWith(loading: true);
      final r = await (await _db.profil).getReglages();
      AppTheme.devise = r.devise; // source unique de vérité
      state = state.copyWith(reglages: r, loading: false);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> save(Reglages r) async {
    await (await _db.profil).updateReglages(r);
    AppTheme.devise = r.devise;
    state = state.copyWith(reglages: r);
  }
}

final reglagesProvider =
    NotifierProvider<ReglagesNotifier, ReglagesViewState>(ReglagesNotifier.new);

// ══════════════════════════════════════════════════════════════
// COMPTEUR ALERTES — badge sur l'icône notifications
// ══════════════════════════════════════════════════════════════

class AlertesCountViewState {
  final int count;

  const AlertesCountViewState({this.count = 0});

  AlertesCountViewState copyWith({int? count}) =>
      AlertesCountViewState(count: count ?? this.count);
}

class AlertesCountNotifier extends Notifier<AlertesCountViewState> {
  final _db = DBHelper.instance;

  @override
  AlertesCountViewState build() {
    final sub = DataBus.instance
        .subscribe([DataTopics.alertes], (_) => refresh());
    ref.onDispose(sub.cancel);
    Future.microtask(refresh);
    return const AlertesCountViewState();
  }

  Future<void> refresh() async {
    final n = await (await _db.alertes).countAlertesNonLues();
    state = AlertesCountViewState(count: n);
  }
}

final alertesCountProvider =
    NotifierProvider<AlertesCountNotifier, AlertesCountViewState>(
        AlertesCountNotifier.new);

// ══════════════════════════════════════════════════════════════
// SESSION LOCALE (lock screen) — singleton SessionManager
// ══════════════════════════════════════════════════════════════

/// Verrou local : statut de la session (locked/unlocked).
/// SessionManager reste un singleton ChangeNotifier — pour le moment, on
/// le wrappe simplement. Une migration future le portera en Notifier pur
/// (impact AuthGate + lock_screen).
final sessionManagerProvider =
    ChangeNotifierProvider<SessionManager>((ref) => SessionManager.instance);
