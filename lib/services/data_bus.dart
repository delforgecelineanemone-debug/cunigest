// ──────────────────────────────────────────────────────────────
// DataBus — broadcast central des changements de données (V3.0)
// ──────────────────────────────────────────────────────────────
// Singleton léger qui notifie l'UI dès qu'une table locale est
// modifiée — peu importe la source du changement :
//   - submit d'un formulaire dans l'app
//   - pull cloud (SyncService applique des modifs distantes)
//   - import / restauration de sauvegarde
//   - opération en arrière-plan
//
// Tous les écrans / providers qui dépendent d'une table s'abonnent
// au topic correspondant et se rafraîchissent automatiquement.
//
// Pas de dépendance externe — c'est juste un StreamController.
// ──────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Identifiants stables des "topics" — un par table métier.
/// Les noms correspondent exactement aux noms de tables SQLite
/// pour éviter toute ambiguïté.
class DataTopics {
  DataTopics._();

  static const String lapins = 'lapins';
  static const String saillies = 'saillies';
  static const String soins = 'soins';
  static const String stocks = 'stocks';
  static const String ventes = 'ventes';
  static const String depenses = 'depenses';
  static const String lots = 'lots';
  static const String pesees = 'pesees';
  static const String distributionsAliment = 'distributions_aliment';
  static const String cages = 'cages';
  static const String batiments = 'batiments';
  static const String clapiers = 'clapiers';
  static const String mouvementsCage = 'mouvements_cage';
  static const String peseesLapin = 'pesees_lapin';
  static const String alertes = 'alertes';
  static const String taches = 'taches';
  static const String completions = 'completions';
  static const String profil = 'profil';
  static const String reglages = 'reglages';

  /// Émis chaque fois que `sync_config` est mis à jour (création/MAJ
  /// du compte, refresh des tokens, sync terminée, déliage…).
  /// Permet à SyncScreen et autres UIs de se rafraîchir.
  static const String syncConfig = 'sync_config';

  /// Émis quand des éléments sont ajoutés / retirés de la sync_queue
  /// (pour mettre à jour le compteur "en attente" dans l'UI).
  static const String syncQueue = 'sync_queue';

  /// Topic spécial : utilisé après un pull cloud bulk ou une restauration
  /// de sauvegarde, pour forcer tous les écrans à se rafraîchir.
  static const String all = '*';
}

class DataBus {
  DataBus._();
  static final DataBus instance = DataBus._();

  final StreamController<String> _controller = StreamController<String>.broadcast();

  /// Flux brut — utile pour debug / tests. Préférer `subscribe()`.
  Stream<String> get stream => _controller.stream;

  /// Publie un événement sur un topic.
  /// Les listeners abonnés au topic OU au topic `*` reçoivent l'événement.
  void notify(String topic) {
    if (_controller.isClosed) return;
    if (kDebugMode) debugPrint('[DataBus] 📣 $topic');
    _controller.add(topic);
  }

  /// Publie plusieurs topics d'un coup (ex. fin d'un pull cloud
  /// qui a touché plusieurs tables).
  void notifyAll(Iterable<String> topics) {
    for (final t in topics) {
      notify(t);
    }
  }

  /// S'abonne à un ou plusieurs topics. Le callback est invoqué
  /// dès qu'un événement publié correspond — ou si un événement
  /// `*` est publié (invalidation globale).
  ///
  /// Renvoie une `StreamSubscription` à annuler dans `dispose()`.
  StreamSubscription<String> subscribe(
    Iterable<String> topics,
    void Function(String topic) callback,
  ) {
    final set = topics.toSet();
    return _controller.stream.listen((event) {
      if (event == DataTopics.all || set.contains(event)) {
        callback(event);
      }
    });
  }

  /// Pour les tests uniquement.
  @visibleForTesting
  void resetForTests() {
    // Ne pas fermer le controller (broadcast non re-créable proprement).
    // On ne fait rien — le singleton reste vivant.
  }
}
