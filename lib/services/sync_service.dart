// ──────────────────────────────────────────────────────────────
// Service : Synchronisation cloud Supabase
// ──────────────────────────────────────────────────────────────
// Implémentation complète :
// - Authentification email/mot de passe (Supabase Auth)
// - Push : envoie chaque entrée de sync_queue → REST Supabase
// - Pull : récupère les rows updated_at > last_sync, applique
//          en local (upsert ou suppression douce via deleted_at)
// - Refresh automatique du token JWT quand il expire
//
// Stratégie de conflit : last-write-wins basé sur updated_at.
// Le pull n'écrase pas les modifications locales pas encore sync
// (filtrage par row_id présent dans sync_queue).
//
// SCHÉMA SERVEUR (déjà créé via la migration cunigest_v2_initial_schema) :
// - lapins, saillies, soins, ventes, stocks, lots, pesees,
//   distributions_aliment
// - Toutes ont user_id (uuid), updated_at (timestamptz), deleted_at,
//   PK composite (user_id, id)
// - RLS activée : auth.uid() = user_id
// ──────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../database/db_helper.dart';
import '../models/sync_entry.dart';
import 'account_service.dart';
import 'certificate_pinning_service.dart';
import 'data_bus.dart';
import 'kpi_service.dart';

/// Mapping table SQLite → topic DataBus. Ajouter ici toute nouvelle
/// table miroir pour propager les changements pull cloud à l'UI.
const Map<String, String> _kTableToTopic = {
  'lapins': DataTopics.lapins,
  'saillies': DataTopics.saillies,
  'soins': DataTopics.soins,
  'stocks': DataTopics.stocks,
  'ventes': DataTopics.ventes,
  'lots': DataTopics.lots,
  'pesees': DataTopics.pesees,
  'distributions_aliment': DataTopics.distributionsAliment,
  // V3.1 — tables ajoutées pour couverture complète
  'depenses': DataTopics.depenses,
  'batiments': DataTopics.batiments,
  'clapiers': DataTopics.clapiers,
  'cages': DataTopics.cages,
  'mouvements_cage': DataTopics.mouvementsCage,
  'pesees_lapin': DataTopics.peseesLapin,
  // V17 — tables ajoutées (couverture exhaustive multi-device)
  'consommations': DataTopics.stocks,
  'lot_lapins': DataTopics.lots,
  'taches_quotidiennes': DataTopics.taches,
  'completions': DataTopics.completions,
  'profil_eleveur': DataTopics.profil,
  'reglages': DataTopics.reglages,
};

/// Liste ordonnée des tables à synchroniser.
/// L'ordre garantit l'intégrité référentielle au pull (parents avant enfants).
const List<String> kSyncedTables = [
  // Hiérarchie cages (parents → enfants)
  'batiments',
  'clapiers',
  'cages',
  // Cheptel principal
  'lapins',         // Référencé par saillies/soins/ventes/mouvements/pesées
  'lots',           // Référencé par pesees/distributions
  'stocks',         // Référencé par distributions
  // Mouvements & événements liés au cheptel
  'mouvements_cage',
  'pesees_lapin',
  'saillies',
  'soins',
  'ventes',
  'depenses',
  // Lots — production
  'pesees',
  'distributions_aliment',
  // V17 — données auxiliaires (consommation, routines, profil utilisateur)
  // pour qu'un changement de téléphone restaure un état complet.
  'consommations',
  'lot_lapins',
  'taches_quotidiennes',
  'completions',
  'profil_eleveur',
  'reglages',
];

/// Résultat d'une opération de synchronisation
class SyncReport {
  final bool success;
  final int pushed;
  final int pulled;
  final int errors;
  final String? message;

  const SyncReport({
    required this.success,
    this.pushed = 0,
    this.pulled = 0,
    this.errors = 0,
    this.message,
  });
}

/// Snapshot d'avancement émis pendant la sync (pour UI premium).
class SyncProgress {
  /// Phase courante : `'preparing' | 'pushing' | 'pulling' | 'finalizing' | 'done'`
  final String phase;

  /// Table en cours de traitement (null en preparing/finalizing/done).
  final String? table;

  /// Nombre d'éléments traités jusqu'ici (push + pull).
  final int processed;

  /// Total estimé d'éléments à traiter (peut être imprécis pour le pull).
  final int total;

  /// Message lisible affichable dans une modale.
  final String message;

  const SyncProgress({
    required this.phase,
    this.table,
    required this.processed,
    required this.total,
    required this.message,
  });

  /// Fraction d'avancement entre 0.0 et 1.0 — utile pour ProgressIndicator.
  /// Retourne null si on ne peut pas estimer (phase pull avant 1ʳᵉ row).
  double? get fraction {
    if (total <= 0) return null;
    final f = processed / total;
    return f.clamp(0.0, 1.0);
  }
}

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  bool _running = false;
  bool _wasOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<String>? _busSub;
  Timer? _autoPushDebounce;

  /// Configuration courante (lue à chaque appel pour rester fraîche).
  Future<SyncConfig> _config() async {
    final repo = await DBHelper.instance.sync;
    return repo.getConfig();
  }

  /// Vérifie si la sync est configurée, activée et authentifiée.
  Future<bool> isReady() async {
    final cfg = await _config();
    return cfg.enabled &&
        cfg.serverUrl != null &&
        cfg.serverUrl!.isNotEmpty &&
        cfg.apiKey != null &&
        cfg.apiKey!.isNotEmpty &&
        cfg.isAuthenticated;
  }

  // ═══════════════════════════════════════════════════════════
  // AUTHENTIFICATION
  // ═══════════════════════════════════════════════════════════

  /// S'inscrit avec email + mot de passe.
  /// Retourne null en cas de succès, sinon un message d'erreur.
  Future<String?> signUp({
    required String serverUrl,
    required String apiKey,
    required String email,
    required String password,
  }) async {
    try {
      final url =
          '${_clean(serverUrl)}/auth/v1/signup';
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'apikey': apiKey, 'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 300) {
        return _traduireErreurServeur(response.body);
      }
      return null;
    } catch (e) {
      return 'Pas d\'internet, réessaye dans un moment.';
    }
  }

  /// Se connecte avec email + mot de passe.
  /// Retourne null en cas de succès et stocke le token dans sync_config.
  Future<String?> signIn({
    required String serverUrl,
    required String apiKey,
    required String email,
    required String password,
  }) async {
    try {
      final url =
          '${_clean(serverUrl)}/auth/v1/token?grant_type=password';
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'apikey': apiKey, 'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 300) {
        return _traduireErreurServeur(response.body);
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = body['access_token'] as String?;
      final refreshToken = body['refresh_token'] as String?;
      final user = body['user'] as Map<String, dynamic>?;
      final userId = user?['id'] as String?;

      if (accessToken == null || userId == null) {
        return 'Réponse inattendue. Réessaye plus tard.';
      }

      final repo = await DBHelper.instance.sync;
      final cfg = await repo.getConfig();
      await repo.updateConfig(cfg.copyWith(
        serverUrl: serverUrl,
        apiKey: apiKey,
        email: email,
        accessToken: accessToken,
        refreshToken: refreshToken,
        userId: userId,
      ));
      return null;
    } catch (e) {
      return 'Pas d\'internet, réessaye dans un moment.';
    }
  }

  /// Se déconnecte (efface les tokens locaux ; n'invalide pas côté serveur).
  Future<void> signOut() async {
    final repo = await DBHelper.instance.sync;
    final cfg = await repo.getConfig();
    await repo.updateConfig(cfg.copyWith(clearAuth: true, enabled: false));
  }

  /// Renouvelle l'access_token via le refresh_token (version publique).
  /// Lit la config courante et tente le refresh — utilisée par CloudAuthService
  /// pour le refresh proactif au démarrage.
  Future<bool> refreshTokenIfPossible() async {
    final cfg = await _config();
    if (cfg.refreshToken == null || cfg.refreshToken!.isEmpty) return false;
    if (cfg.serverUrl == null || cfg.apiKey == null) return false;
    return _refreshToken(cfg);
  }

  /// Renouvelle l'access_token via le refresh_token.
  /// Appelé automatiquement quand un appel renvoie 401.
  Future<bool> _refreshToken(SyncConfig cfg) async {
    if (cfg.refreshToken == null) return false;
    try {
      final url =
          '${_clean(cfg.serverUrl!)}/auth/v1/token?grant_type=refresh_token';
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'apikey': cfg.apiKey!, 'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': cfg.refreshToken}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 300) return false;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = body['access_token'] as String?;
      final refreshToken = body['refresh_token'] as String?;
      if (accessToken == null) return false;

      final repo = await DBHelper.instance.sync;
      await repo.updateConfig(cfg.copyWith(
        accessToken: accessToken,
        refreshToken: refreshToken,
      ));
      return true;
    } catch (_) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // SYNC PRINCIPALE
  // ═══════════════════════════════════════════════════════════

  /// Lance une synchronisation complète (push + pull).
  /// Idempotent : retourne immédiatement si déjà en cours.
  Future<SyncReport> synchroniser({void Function(SyncProgress)? onProgress}) async {
    if (_running) {
      return const SyncReport(success: false, message: 'Sauvegarde déjà en cours');
    }
    debugPrint('SYNC ▶ démarrage');
    onProgress?.call(const SyncProgress(
      phase: 'preparing',
      processed: 0,
      total: 0,
      message: 'Préparation de la sauvegarde…',
    ));
    if (!await _isOnline()) {
      debugPrint('SYNC ⏸ hors-ligne');
      return const SyncReport(
        success: false,
        message: 'Pas de réseau. La sauvegarde reprendra automatiquement.',
      );
    }
    _running = true;

    try {
      var cfg = await _config();
      if (cfg.serverUrl == null || cfg.apiKey == null ||
          cfg.serverUrl!.isEmpty || cfg.apiKey!.isEmpty) {
        debugPrint('SYNC ❌ serverUrl/apiKey vide');
        return const SyncReport(
            success: false,
            message: 'Sauvegarde cloud non disponible. Réinstalle l\'app.');
      }
      // Si le compte n'est pas encore lié au cloud (premier essai après
      // création offline du compte), tenter le lien maintenant.
      if (!cfg.isCloudLinked) {
        debugPrint('SYNC 🔗 compte pas encore lié, tentative…');
        await AccountService.instance.tenterLienCloud();
        cfg = await _config();
      }
      if (!cfg.isCloudLinked) {
        debugPrint('SYNC ❌ compte non lié au cloud après tentative');
        return const SyncReport(
            success: false,
            message: 'Pas de réseau pour la sauvegarde cloud. Réessaye plus tard.');
      }
      debugPrint(
          'SYNC ✅ lié (userId=${cfg.userId?.substring(0, 8)}…) — push…');

      // P3.19 — Pre-flight certificate pinning : si activé, on vérifie
      // l'empreinte TLS du serveur AVANT d'envoyer le moindre token.
      // Bloque un proxy hostile / faux point d'accès Wi-Fi.
      if (CertificatePinningService.instance.isEnabled) {
        final safe = await CertificatePinningService.instance
            .isSafeUrl(cfg.serverUrl!);
        if (!safe) {
          debugPrint('SYNC 🛑 certificat non reconnu — sync annulée (MITM ?)');
          return const SyncReport(
            success: false,
            message:
                'Connexion non sécurisée détectée. Sauvegarde annulée par précaution. '
                'Change de réseau Wi-Fi et réessaye.',
          );
        }
      }

      // 1. PUSH des modifications locales
      final pushReport = await _pushPending(cfg, onProgress: onProgress);
      debugPrint(
          'SYNC ⬆ push : ${pushReport.success} OK, ${pushReport.errors} erreurs');

      // 2. PULL des modifications distantes
      cfg = await _config(); // Recharge pour avoir un éventuel token rafraîchi
      debugPrint('SYNC ⬇ pull…');
      onProgress?.call(SyncProgress(
        phase: 'pulling',
        processed: pushReport.success,
        total: pushReport.success,
        message: 'Récupération des changements cloud…',
      ));
      final pullReport = await _pullDistant(cfg);
      debugPrint(
          'SYNC ⬇ pull : ${pullReport.success} OK, ${pullReport.errors} erreurs');

      // 3. Mise à jour du timestamp seulement si la sync est complète.
      final repo = await DBHelper.instance.sync;
      if (pushReport.errors == 0 && pullReport.errors == 0) {
        cfg = await _config();
        await repo.updateConfig(
          cfg.copyWith(lastSyncAt: DateTime.now().toUtc().toIso8601String()),
        );
        await repo.nettoyer();
      }

      final allOk = pushReport.errors == 0 && pullReport.errors == 0;
      KpiService.instance
          .track(allOk ? KpiEvent.syncReussie : KpiEvent.syncEchouee);
      return SyncReport(
        success: allOk,
        pushed: pushReport.success,
        pulled: pullReport.success,
        errors: pushReport.errors + pullReport.errors,
        message: allOk
            ? 'Sauvegarde terminée (${pushReport.success} envoyés, ${pullReport.success} reçus)'
            : 'Sauvegarde partielle (${pushReport.errors + pullReport.errors} éléments en attente)',
      );
    } catch (e) {
      debugPrint('Sync échec : $e');
      KpiService.instance.track(KpiEvent.syncEchouee);
      return const SyncReport(
        success: false,
        message: 'Sauvegarde impossible. Vérifie ta connexion.',
      );
    } finally {
      _running = false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // INITIAL FULL PUSH — pour les données pré-existantes au cloud
  // ═══════════════════════════════════════════════════════════

  /// Ajoute toutes les lignes existantes des tables miroirs à la
  /// `sync_queue` comme INSERT.
  ///
  /// Comportement :
  /// - Si [forceAll] est `false` (défaut) : ignore les rows déjà connues
  ///   de la sync_queue (déjà push ou en attente). **Idempotent**.
  /// - Si [forceAll] est `true` : enqueue TOUTES les rows, peu importe
  ///   l'historique de la sync_queue. **Utile au changement de cloud
  ///   user** : les rows déjà push à l'ancien userId sont re-push au
  ///   nouveau.
  ///
  /// Retourne le nombre de lignes ajoutées à la file.
  Future<int> enqueueAllExistingRows({bool forceAll = false}) async {
    final db = await DBHelper.instance.database;
    final syncRepo = await DBHelper.instance.sync;
    int enqueued = 0;

    for (final table in kSyncedTables) {
      try {
        // 1. Si !forceAll, récupère les row_ids déjà connus pour skip.
        Set<int> knownIds = const {};
        if (!forceAll) {
          final knownRows = await db.rawQuery(
            'SELECT DISTINCT row_id FROM sync_queue WHERE table_name = ?',
            [table],
          );
          knownIds = knownRows.map((r) => r['row_id'] as int).toSet();
        }

        // 2. Liste toutes les rows actuelles de la table.
        final rows = await db.query(table);
        int addedForTable = 0;
        for (final row in rows) {
          final id = row['id'] as int?;
          if (id == null) {
            debugPrint('SYNC 🆕 ⚠ $table : row sans id ignorée — $row');
            continue;
          }
          if (!forceAll && knownIds.contains(id)) continue;

          await syncRepo.enqueue(
            tableName: table,
            rowId: id,
            operation: 'insert',
            payload: row,
          );
          addedForTable++;
          enqueued++;
        }
        debugPrint(
            'SYNC 🆕 $table : ${rows.length} lignes, +$addedForTable en file${forceAll ? ' (force)' : ''}');
      } catch (e) {
        debugPrint('SYNC 🆕 ⚠ $table : $e');
      }
    }

    debugPrint('SYNC 🆕 total ajouté à la file : $enqueued${forceAll ? ' (force)' : ''}');
    return enqueued;
  }

  // ── PUSH ──

  Future<({int success, int errors})> _pushPending(
    SyncConfig cfg, {
    void Function(SyncProgress)? onProgress,
  }) async {
    final repo = await DBHelper.instance.sync;
    final pending = await repo.getPending(limit: 500);
    int success = 0;
    int errors = 0;
    final total = pending.length;

    debugPrint('SYNC ⬆ $total élément(s) en file');
    onProgress?.call(SyncProgress(
      phase: 'pushing',
      processed: 0,
      total: total,
      message: total == 0
          ? 'Aucune modification à envoyer'
          : 'Envoi de $total modification${total > 1 ? "s" : ""}…',
    ));

    int processed = 0;
    for (final entry in pending) {
      processed++;
      // On ne synchronise que les tables miroirs présentes côté serveur
      if (!kSyncedTables.contains(entry.tableName)) {
        debugPrint(
            'SYNC ⬆ skip ${entry.tableName} (pas dans kSyncedTables)');
        await repo.markSynced(entry.id!);
        continue;
      }
      try {
        await _pushOne(cfg, entry);
        await repo.markSynced(entry.id!);
        success++;
        debugPrint(
            'SYNC ⬆ ✅ ${entry.operation} ${entry.tableName} #${entry.rowId}');
      } catch (e) {
        await repo.markFailed(entry.id!, e.toString());
        errors++;
        debugPrint(
            'SYNC ⬆ ❌ ${entry.operation} ${entry.tableName} #${entry.rowId} — $e');
      }
      onProgress?.call(SyncProgress(
        phase: 'pushing',
        table: entry.tableName,
        processed: processed,
        total: total,
        message: 'Envoi : $processed / $total — ${_humanTable(entry.tableName)}',
      ));
    }
    return (success: success, errors: errors);
  }

  /// Nom lisible d'une table pour les messages UI.
  String _humanTable(String t) => switch (t) {
        'lapins' => 'lapins',
        'saillies' => 'saillies',
        'soins' => 'soins',
        'ventes' => 'ventes',
        'stocks' => 'stocks',
        'lots' => 'lots',
        'pesees' => 'pesées (lots)',
        'pesees_lapin' => 'pesées (individuelles)',
        'distributions_aliment' => 'distributions',
        'depenses' => 'dépenses',
        'cages' => 'cages',
        'batiments' => 'bâtiments',
        'clapiers' => 'clapiers',
        'mouvements_cage' => 'déplacements',
        _ => t,
      };

  Future<void> _pushOne(SyncConfig cfg, SyncEntry entry) async {
    final url = '${_clean(cfg.serverUrl!)}/rest/v1/${entry.tableName}';
    final payload = Map<String, dynamic>.from(jsonDecode(entry.payloadJson));
    payload['user_id'] = cfg.userId;

    http.Response response;
    switch (entry.operation) {
      case 'insert':
      case 'update':
        // upsert par PK (user_id, id) — Supabase gère via on_conflict
        response = await _request(
          cfg,
          'POST',
          '$url?on_conflict=user_id,id',
          body: jsonEncode([payload]),
          extraHeaders: {
            'Prefer': 'resolution=merge-duplicates,return=minimal',
          },
        );
        break;
      case 'delete':
        // Soft-delete : marque deleted_at
        response = await _request(
          cfg,
          'PATCH',
          '$url?id=eq.${entry.rowId}&user_id=eq.${cfg.userId}',
          body: jsonEncode({
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
          }),
        );
        break;
      default:
        throw Exception('Opération inconnue : ${entry.operation}');
    }

    if (response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode} : ${response.body}');
    }
  }

  // ── PULL ──

  /// Pull les modifications distantes plus récentes que la dernière sync.
  /// Applique upsert/delete localement, en respectant les modifications
  /// pas encore poussées (pour ne rien écraser).
  Future<({int success, int errors})> _pullDistant(SyncConfig cfg) async {
    int success = 0;
    int errors = 0;
    // Tables dont au moins une ligne a été modifiée localement par le pull —
    // on broadcast sur le DataBus à la fin pour que toute l'UI se rafraîchisse.
    final tablesTouched = <String>{};
    final lastSync = cfg.lastSyncAt ?? '1970-01-01T00:00:00Z';

    // Récupérer la liste des row_ids non encore synchronisés (qu'on ne veut
    // PAS écraser par le pull) — par table.
    final pendingPerTable = await _pendingRowIdsPerTable();

    for (final table in kSyncedTables) {
      try {
        final pending = pendingPerTable[table] ?? <int>{};
        var offset = 0;
        const pageSize = 500;

        while (true) {
          final url =
              '${_clean(cfg.serverUrl!)}/rest/v1/$table'
              '?updated_at=gt.${Uri.encodeComponent(lastSync)}'
              '&user_id=eq.${cfg.userId}'
              '&order=updated_at.asc'
              '&limit=$pageSize'
              '&offset=$offset';
          final response = await _request(cfg, 'GET', url);
          if (response.statusCode >= 300) {
            throw Exception('HTTP ${response.statusCode}');
          }
          final List rows = jsonDecode(response.body) as List;
          if (rows.isEmpty) break;

          final db = await DBHelper.instance.database;
          await db.transaction((txn) async {
            for (final row in rows) {
              final m = Map<String, dynamic>.from(row as Map);
              final rowId = m['id'] as int?;
              if (rowId == null) continue;
              // Ne pas écraser les modifications locales en attente
              if (pending.contains(rowId)) continue;

              try {
                await _applyRowToLocal(table, m, txn: txn);
                tablesTouched.add(table);
                success++;
              } catch (e) {
                debugPrint('Pull apply échec $table:$rowId — $e');
                errors++;
              }
            }
          });

          if (rows.length < pageSize) {
            break;
          }
          offset += pageSize;
        }
      } catch (e) {
        debugPrint('Pull table $table échec : $e');
        errors++;
      }
    }

    // Broadcast les changements aux écrans abonnés — la magie de la sync :
    // si un autre téléphone a ajouté un lapin, il apparaît instantanément
    // dans la liste ouverte sans aucune action de l'utilisateur.
    if (tablesTouched.isNotEmpty) {
      final topics = tablesTouched
          .map((t) => _kTableToTopic[t])
          .whereType<String>()
          .toList();
      if (topics.isNotEmpty) {
        debugPrint('Sync pull → broadcast topics: $topics');
        DataBus.instance.notifyAll(topics);
      }
    }

    // Pruning du log de conflits (rotation FIFO à 200 entrées) — hors
    // transaction de pull pour ne pas allonger les locks SQLite.
    try {
      final repo = await DBHelper.instance.sync;
      await repo.pruneConflicts();
    } catch (e) {
      debugPrint('SYNC ⚠ pruneConflicts échoué : $e');
    }

    return (success: success, errors: errors);
  }

  /// Récupère les row_ids en attente de push, indexés par table.
  Future<Map<String, Set<int>>> _pendingRowIdsPerTable() async {
    final db = await DBHelper.instance.database;
    final rows = await db.rawQuery(
      'SELECT table_name, row_id FROM sync_queue WHERE synced_at IS NULL',
    );
    final result = <String, Set<int>>{};
    for (final r in rows) {
      final t = r['table_name'] as String;
      final id = r['row_id'] as int;
      result.putIfAbsent(t, () => <int>{}).add(id);
    }
    return result;
  }

  /// Applique une ligne reçue du serveur dans la base locale.
  /// - Si `deleted_at` non null côté remote → soft-delete local (jamais hard,
  ///   pour préserver la récupération si pull est partiel/replayable).
  /// - Sinon → last-write-wins basé sur `updated_at` (skip si local plus
  ///   récent), puis upsert en conservant `updated_at` local pour audit.
  ///
  /// Écrasement de conflit : si une row locale existante avec son propre
  /// `updated_at` non-null est remplacée par une row distante plus récente
  /// (cas typique : un autre téléphone a modifié la même fiche entre temps),
  /// on enregistre une trace dans `conflict_log` pour que l'éleveur puisse
  /// comprendre où sa modif a « disparu ».
  Future<void> _applyRowToLocal(
    String table,
    Map<String, dynamic> row, {
    DatabaseExecutor? txn,
  }) async {
    final executor = txn ?? await DBHelper.instance.database;

    final id = row['id'] as int?;
    if (id == null) return;

    final remoteDeletedAt = row['deleted_at'] as String?;
    final remoteUpdatedAt = row['updated_at'] as String?;

    // Soft-delete remote → soft-delete local (pas de hard delete)
    if (remoteDeletedAt != null) {
      await executor.update(
        table,
        {'deleted_at': remoteDeletedAt, 'updated_at': remoteUpdatedAt ?? remoteDeletedAt},
        where: 'id = ?',
        whereArgs: [id],
      );
      return;
    }

    // Last-write-wins : si la version locale est plus récente, on garde.
    String? localUpdatedAt;
    var isExistingRow = false;
    if (remoteUpdatedAt != null) {
      final existing = await executor.query(
        table,
        columns: ['updated_at'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        isExistingRow = true;
        localUpdatedAt = existing.first['updated_at'] as String?;
        if (localUpdatedAt != null && localUpdatedAt.compareTo(remoteUpdatedAt) >= 0) {
          // Local est aussi récent ou plus récent → ne pas écraser
          return;
        }
      }
    }

    // Conflit détecté : on s'apprête à écraser une row locale existante qui
    // avait un updated_at non-null distinct du remote → trace d'audit.
    // L'insertion se fait dans la même transaction que l'update pour rester
    // atomique : si le commit échoue, le log disparaît aussi.
    if (isExistingRow &&
        localUpdatedAt != null &&
        remoteUpdatedAt != null &&
        localUpdatedAt != remoteUpdatedAt) {
      try {
        final syncRepo = await DBHelper.instance.sync;
        await syncRepo.recordConflict(
          tableName: table,
          rowId: id,
          localUpdatedAt: localUpdatedAt,
          remoteUpdatedAt: remoteUpdatedAt,
          executor: executor,
        );
        debugPrint(
            'SYNC ⚠ conflit LWW : $table#$id (local=$localUpdatedAt < remote=$remoteUpdatedAt)');
      } catch (e) {
        debugPrint('SYNC ⚠ log conflit échoué : $e');
      }
    }

    // Retirer les colonnes propres au serveur (mais conserver updated_at /
    // deleted_at pour LWW futur). user_id non stocké en local : seul le
    // sync_config contient le user courant.
    final clean = Map<String, dynamic>.from(row);
    clean.remove('user_id');

    // Sanitize : convertir les bool en int (SQLite n'a pas de bool)
    clean.updateAll((k, v) {
      if (v is bool) return v ? 1 : 0;
      return v;
    });

    final updated = await executor.update(
      table,
      clean,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated == 0) {
      await executor.insert(table, clean);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // HTTP : auth + retry on 401
  // ═══════════════════════════════════════════════════════════

  /// Effectue une requête HTTP avec auth et retry automatique sur 401.
  Future<http.Response> _request(
    SyncConfig cfg,
    String method,
    String url, {
    String? body,
    Map<String, String>? extraHeaders,
  }) async {
    Future<http.Response> doRequest(SyncConfig c) {
      final headers = <String, String>{
        'apikey': c.apiKey!,
        'Authorization': 'Bearer ${c.accessToken!}',
        'Content-Type': 'application/json',
        ...?extraHeaders,
      };
      switch (method) {
        case 'GET':
          return http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 8));
        case 'POST':
          return http.post(Uri.parse(url), headers: headers, body: body).timeout(const Duration(seconds: 8));
        case 'PATCH':
          return http.patch(Uri.parse(url), headers: headers, body: body).timeout(const Duration(seconds: 8));
        case 'DELETE':
          return http.delete(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 8));
        default:
          throw ArgumentError('Méthode HTTP inconnue : $method');
      }
    }

    var response = await doRequest(cfg);
    if (response.statusCode == 401) {
      // Token expiré → tentative de refresh puis retry une fois
      final refreshed = await _refreshToken(cfg);
      if (refreshed) {
        final newCfg = await _config();
        response = await doRequest(newCfg);
      }
    }
    return response;
  }

  // ═══════════════════════════════════════════════════════════
  // CONNECTIVITÉ
  // ═══════════════════════════════════════════════════════════

  /// Démarre l'écoute de la connectivité réseau.
  /// Déclenche une sync automatique quand le téléphone se reconnecte.
  /// À appeler une seule fois au démarrage de l'app.
  void listenConnectivity() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline && _wasOffline) {
        debugPrint('Sync ↑ reconnexion détectée — sync auto');
        synchroniser();
      }
      _wasOffline = !isOnline;
    });
  }

  void disposeConnectivity() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  /// Auto-push debounced : écoute le `DataBus.syncQueue` et déclenche
  /// une sauvegarde 3 secondes après la dernière modification locale.
  ///
  /// Résout le problème "les données ne sont prises en compte qu'au
  /// prochain démarrage" — chaque modif locale est poussée vers le
  /// cloud presque immédiatement, sans intervention utilisateur.
  ///
  /// Si l'utilisateur ajoute 10 lapins en 5s, on fait **1 seule sync**
  /// après la dernière modif — pas 10. Économise la batterie et le réseau.
  ///
  /// À appeler une fois au démarrage (depuis main.dart).
  void wireAutoPush() {
    _busSub?.cancel();
    _busSub = DataBus.instance.subscribe(
      const [DataTopics.syncQueue],
      (_) => _scheduleAutoPush(),
    );
    debugPrint('Sync 🤖 auto-push armé (debounce 3s)');
  }

  void _scheduleAutoPush() {
    _autoPushDebounce?.cancel();
    _autoPushDebounce = Timer(const Duration(seconds: 3), () async {
      if (_running) return; // sync déjà en cours
      try {
        final ready = await isReady();
        if (!ready) {
          debugPrint('Sync 🤖 skip auto-push : compte non lié au cloud');
          return;
        }
        debugPrint('Sync 🤖 auto-push déclenché');
        await synchroniser();
      } catch (e) {
        debugPrint('Sync 🤖 auto-push erreur : $e');
      }
    });
  }

  void disposeAutoPush() {
    _busSub?.cancel();
    _busSub = null;
    _autoPushDebounce?.cancel();
    _autoPushDebounce = null;
  }

  Future<bool> _isOnline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true; // En cas d'erreur de détection, on tente quand même
    }
  }

  // ═══════════════════════════════════════════════════════════
  // UTILITAIRES PUBLICS
  // ═══════════════════════════════════════════════════════════

  /// Test de la connexion serveur (sans auth nécessaire)
  Future<bool> testerConnexion(String url, String apiKey) async {
    try {
      final cleanUrl = _clean(url);
      final response = await http.get(
        Uri.parse('$cleanUrl/rest/v1/'),
        headers: {'apikey': apiKey, 'Authorization': 'Bearer $apiKey'},
      ).timeout(const Duration(seconds: 8));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  String _clean(String url) => url.replaceAll(RegExp(r'/$'), '');

  /// Traduit les erreurs serveur en messages français lisibles
  /// pour un éleveur non technique. Évite tout jargon (HTTP, JWT, etc.).
  String _traduireErreurServeur(String body) {
    final raw = body.toLowerCase();
    if (raw.contains('user already registered') ||
        raw.contains('already_exists') ||
        raw.contains('duplicate')) {
      return 'Cet email est déjà utilisé. Connecte-toi avec ton mot de passe.';
    }
    if (raw.contains('invalid login') ||
        raw.contains('invalid_credentials') ||
        raw.contains('invalid grant')) {
      return 'Email ou mot de passe incorrect.';
    }
    if (raw.contains('rate limit') || raw.contains('too many')) {
      return 'Trop d\'essais. Attends un moment avant de réessayer.';
    }
    if (raw.contains('email rate') || raw.contains('weak password')) {
      return 'Mot de passe trop faible. Choisis un mot de passe plus solide.';
    }
    if (raw.contains('email_not_confirmed')) {
      return 'Confirme ton email avant de te connecter.';
    }
    return 'Connexion impossible. Réessaye plus tard.';
  }
}
