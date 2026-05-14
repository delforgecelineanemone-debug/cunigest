// ──────────────────────────────────────────────────────────────
// State Management : Notifiers Provider
// ──────────────────────────────────────────────────────────────
// Encapsule l'état partagé entre écrans :
// - Utilisateur connecté + permissions
// - Liste des lapins (cache + filtre)
// - Profil gamification (streak, score, niveau)
// - Réglages
// - Compteur d'alertes
//
// Architecture : ChangeNotifier classique. À chaque action qui
// modifie l'état, on appelle `notifyListeners()` et tous les
// Consumers/context.watch s'actualisent.
//
// Usage dans un écran :
//   final lapins = context.watch<LapinsState>().filtered;
//   await context.read<LapinsState>().refresh();
// ──────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';
import '../models/lapin.dart';
import '../models/profil.dart';
import '../models/reglages.dart';
import '../models/user.dart';
import '../services/image_service.dart';
import '../utils/theme.dart';

/// Session utilisateur courante
class SessionState extends ChangeNotifier {
  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.role == 'admin';
  bool get peutVoirFinances => _currentUser?.peutVoirFinances ?? true;
  bool get peutSupprimer => _currentUser?.peutSupprimer ?? true;
  bool get peutModifierReglages => _currentUser?.peutModifierReglages ?? true;

  void login(AppUser user) {
    _currentUser = user;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  /// Mode "solo legacy" : pas d'utilisateur défini (DB sans table users
  /// peuplée) → tout est autorisé comme en V1.
  void setSoloLegacy() {
    _currentUser = null;
    notifyListeners();
  }
}

/// État des lapins (liste + filtres + recherche)
class LapinsState extends ChangeNotifier {
  final db = DBHelper.instance;

  List<Lapin> _all = [];
  String _search = '';
  String _filtreStatut = 'tous';
  bool _loading = false;

  List<Lapin> get all => _all;
  String get search => _search;
  String get filtreStatut => _filtreStatut;
  bool get loading => _loading;

  /// Lapins filtrés selon recherche + statut
  List<Lapin> get filtered {
    return _all.where((l) {
      final matchSearch = _search.isEmpty ||
          l.numeroBague.toLowerCase().contains(_search.toLowerCase()) ||
          (l.nom?.toLowerCase().contains(_search.toLowerCase()) ?? false);
      final matchStatut = _filtreStatut == 'tous' || l.statut == _filtreStatut;
      return matchSearch && matchStatut;
    }).toList();
  }

  Map<int, Lapin> get byId => {for (var l in _all) if (l.id != null) l.id!: l};

  int get nbActifs => _all.where((l) => l.statut == 'actif').length;
  int get nbMales =>
      _all.where((l) => l.sexe == 'male' && l.statut == 'actif').length;
  int get nbFemelles =>
      _all.where((l) => l.sexe == 'femelle' && l.statut == 'actif').length;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    _all = await db.getAllLapins();
    _loading = false;
    notifyListeners();
  }

  void setSearch(String s) {
    _search = s;
    notifyListeners();
  }

  void setFiltreStatut(String s) {
    _filtreStatut = s;
    notifyListeners();
  }

  Future<int> ajouter(Lapin l) async {
    final id = await db.insertLapin(l);
    await refresh();
    return id;
  }

  Future<int> modifier(Lapin l) async {
    final r = await db.updateLapin(l);
    await refresh();
    return r;
  }

  Future<int> supprimer(int id) async {
    final photoPath = _all.where((l) => l.id == id).firstOrNull?.photoPath;
    final r = await db.deleteLapin(id);
    if (photoPath != null) await ImageService.deletePhoto(photoPath);
    await refresh();
    return r;
  }
}

/// État du profil gamification
class ProfilState extends ChangeNotifier {
  final db = DBHelper.instance;

  ProfilEleveur _profil = ProfilEleveur();
  bool _loading = false;

  ProfilEleveur get profil => _profil;
  bool get loading => _loading;
  int get streak => _profil.streakActuel;
  int get niveau => _profil.niveau;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    _profil = await db.getProfil();
    _loading = false;
    notifyListeners();
  }

  Future<void> completerTache(int tacheId, int points) async {
    await db.completerTache(tacheId);
    _profil = await db.mettreAJourScore(points);
    notifyListeners();
  }

  Future<void> deCompleterTache(int tacheId, int points) async {
    await db.deCompleterTache(tacheId);
    _profil = await db.mettreAJourScore(-points);
    notifyListeners();
  }
}

/// État des réglages
class ReglagesState extends ChangeNotifier {
  final db = DBHelper.instance;

  Reglages _reglages = const Reglages();
  bool _loading = false;

  Reglages get reglages => _reglages;
  bool get loading => _loading;
  bool get gamificationActive => _reglages.gamificationActive;
  bool get notificationsActives => _reglages.notificationsActives;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    _reglages = await db.getReglages();
    AppTheme.devise = _reglages.devise; // source unique de vérité
    _loading = false;
    notifyListeners();
  }

  Future<void> save(Reglages r) async {
    await db.updateReglages(r);
    _reglages = r;
    AppTheme.devise = r.devise; // source unique de vérité
    notifyListeners();
  }
}

/// État du compteur d'alertes (pour badge sur l'icône notifications)
class AlertesCountState extends ChangeNotifier {
  final db = DBHelper.instance;

  int _count = 0;
  int get count => _count;

  Future<void> refresh() async {
    _count = await db.countAlertesNonLues();
    notifyListeners();
  }
}
