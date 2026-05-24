// ──────────────────────────────────────────────────────────────
// RealtimeService — abonnements Supabase Realtime (V3.1)
// ──────────────────────────────────────────────────────────────
// S'abonne aux changements PostgreSQL des 8 tables métier via
// WebSocket. À chaque event reçu (INSERT/UPDATE/DELETE depuis un
// AUTRE appareil du même user), publie sur le DataBus → l'UI se
// rafraîchit instantanément.
//
// Architecture :
//   - 1 channel global "cunigest:<user_id>"
//   - 8 listeners (postgres_changes) — un par table
//   - Filtrage côté serveur : user_id = <auth.uid()>
//   - Lifecycle : start au login, stop au logout / sign-out
//   - Reconnexion automatique gérée par supabase_flutter
//
// Sécurité : RLS appliquée par Supabase, on ne reçoit que SES rows.
// ──────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data_bus.dart';
import 'sync_service.dart';

class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  RealtimeChannel? _channel;
  String? _activeUserId;
  StreamSubscription<AuthState>? _authSub;
  Timer? _pullDebounce;

  bool get isActive => _channel != null;

  /// Démarre les abonnements Realtime pour l'utilisateur courant.
  /// Idempotent : appel multiple OK, retourne immédiatement si déjà actif
  /// pour le même user.
  ///
  /// Appelle aussi `start()` automatiquement à chaque login détecté
  /// via `onAuthStateChange` — l'appelant n'a qu'à invoquer `wireUp()`
  /// une seule fois au boot.
  Future<void> start() async {
    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      final userId = session?.user.id;

      if (userId == null) {
        debugPrint('Realtime: pas de session, abandon');
        return;
      }
      if (_activeUserId == userId && _channel != null) {
        return; // déjà actif pour ce user
      }

      // Si on était abonné pour un autre user (rare : changement de compte),
      // on nettoie d'abord.
      if (_channel != null) await stop();

      // Mapping table → topic DataBus.
      // Tous les topics correspondent aux noms de tables — c'est la même
      // string, mais on garde le mapping explicite pour les cas spéciaux.
      final tableToTopic = <String, String>{
        'lapins': DataTopics.lapins,
        'saillies': DataTopics.saillies,
        'soins': DataTopics.soins,
        'ventes': DataTopics.ventes,
        'stocks': DataTopics.stocks,
        'lots': DataTopics.lots,
        'pesees': DataTopics.pesees,
        'distributions_aliment': DataTopics.distributionsAliment,
        // V3.1 — 6 tables ajoutées
        'depenses': DataTopics.depenses,
        'batiments': DataTopics.batiments,
        'clapiers': DataTopics.clapiers,
        'cages': DataTopics.cages,
        'mouvements_cage': DataTopics.mouvementsCage,
        'pesees_lapin': DataTopics.peseesLapin,
      };

      final channel = client.channel('cunigest:$userId');

      for (final entry in tableToTopic.entries) {
        final table = entry.key;
        final topic = entry.value;
        channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          // Filtrage serveur : ne reçoit QUE ses propres rows.
          // (Doublé par RLS — défense en profondeur.)
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _onChange(table, topic, payload),
        );
      }

      channel.subscribe((status, err) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          debugPrint('Realtime ✅ abonné (user: $userId)');
        } else if (err != null) {
          debugPrint('Realtime ⚠ $status — $err');
        }
      });

      _channel = channel;
      _activeUserId = userId;
    } catch (e, st) {
      debugPrint('Realtime.start erreur : $e\n$st');
    }
  }

  /// Stoppe l'abonnement courant (logout, changement de compte).
  Future<void> stop() async {
    try {
      final ch = _channel;
      if (ch != null) {
        await Supabase.instance.client.removeChannel(ch);
        debugPrint('Realtime: désabonné');
      }
    } catch (e) {
      debugPrint('Realtime.stop erreur : $e');
    } finally {
      _channel = null;
      _activeUserId = null;
    }
  }

  /// À appeler une fois au boot (depuis main.dart).
  /// Écoute onAuthStateChange pour démarrer/arrêter automatiquement
  /// les abonnements en fonction du cycle de vie de la session.
  void wireUp() {
    _authSub?.cancel();
    try {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final s = data.session;
        if (s != null) {
          // ignore: discarded_futures
          start();
        } else {
          // ignore: discarded_futures
          stop();
        }
      });
      // Démarre tout de suite si une session est déjà valide.
      if (Supabase.instance.client.auth.currentSession != null) {
        // ignore: discarded_futures
        start();
      }
    } catch (e) {
      debugPrint('Realtime.wireUp erreur : $e');
    }
  }

  // ─── Handler d'événements ───────────────────────────────────

  void _onChange(
    String table,
    String topic,
    PostgresChangePayload payload,
  ) {
    if (kDebugMode) {
      debugPrint(
          'Realtime 📡 $table ${payload.eventType.name} (id=${payload.newRecord['id'] ?? payload.oldRecord['id']})');
    }

    // 1. Notifie l'UI immédiatement — les écrans abonnés au topic
    //    se rafraîchissent depuis la DB locale.
    DataBus.instance.notify(topic);

    // 2. Déclenche un pull cloud debounced pour mettre à jour la DB
    //    locale avec les changements distants. Le pull a déjà la
    //    logique "ne pas écraser ce qui n'a pas été pushé".
    _schedulePullSync();
  }

  /// Coalesce plusieurs events Realtime rapprochés en un seul pull
  /// (ex. l'autre téléphone fait 5 modifs en 2 secondes).
  void _schedulePullSync() {
    _pullDebounce?.cancel();
    _pullDebounce = Timer(const Duration(milliseconds: 800), () {
      // ignore: discarded_futures
      SyncService.instance.synchroniser();
    });
  }
}
