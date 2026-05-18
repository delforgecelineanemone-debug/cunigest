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

/// Liste ordonnée des tables à synchroniser.
/// L'ordre garantit l'intégrité référentielle au pull (parents avant enfants).
const List<String> kSyncedTables = [
  'lapins',         // Référencé par saillies/soins/ventes
  'lots',           // Référencé par pesees/distributions
  'stocks',         // Référencé par distributions
  'saillies',
  'soins',
  'ventes',
  'pesees',
  'distributions_aliment',
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

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  bool _running = false;
  bool _wasOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

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
  Future<SyncReport> synchroniser() async {
    if (_running) {
      return const SyncReport(success: false, message: 'Sauvegarde déjà en cours');
    }
    if (!await _isOnline()) {
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
        return const SyncReport(
            success: false,
            message: 'Sauvegarde cloud non disponible. Réinstalle l\'app.');
      }
      // Si le compte n'est pas encore lié au cloud (premier essai après
      // création offline du compte), tenter le lien maintenant.
      if (!cfg.isCloudLinked) {
        await AccountService.instance.tenterLienCloud();
        cfg = await _config();
      }
      if (!cfg.isCloudLinked) {
        return const SyncReport(
            success: false,
            message: 'Pas de réseau pour la sauvegarde cloud. Réessaye plus tard.');
      }

      // 1. PUSH des modifications locales
      final pushReport = await _pushPending(cfg);

      // 2. PULL des modifications distantes
      cfg = await _config(); // Recharge pour avoir un éventuel token rafraîchi
      final pullReport = await _pullDistant(cfg);

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
      return const SyncReport(
        success: false,
        message: 'Sauvegarde impossible. Vérifie ta connexion.',
      );
    } finally {
      _running = false;
    }
  }

  // ── PUSH ──

  Future<({int success, int errors})> _pushPending(SyncConfig cfg) async {
    final repo = await DBHelper.instance.sync;
    final pending = await repo.getPending(limit: 200);
    int success = 0;
    int errors = 0;

    for (final entry in pending) {
      // On ne synchronise que les tables miroirs présentes côté serveur
      if (!kSyncedTables.contains(entry.tableName)) {
        await repo.markSynced(entry.id!);
        continue;
      }
      try {
        await _pushOne(cfg, entry);
        await repo.markSynced(entry.id!);
        success++;
      } catch (e) {
        await repo.markFailed(entry.id!, e.toString());
        errors++;
      }
    }
    return (success: success, errors: errors);
  }

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
  /// - Si `deleted_at` non null → supprime localement
  /// - Sinon → upsert sans REPLACE en retirant les colonnes serveur
  Future<void> _applyRowToLocal(
    String table,
    Map<String, dynamic> row, {
    DatabaseExecutor? txn,
  }) async {
    final executor = txn ?? await DBHelper.instance.database;

    final id = row['id'] as int?;
    if (id == null) return;

    // Soft-delete distant → DELETE local
    if (row['deleted_at'] != null) {
      await executor.delete(table, where: 'id = ?', whereArgs: [id]);
      return;
    }

    // Retirer les colonnes propres au serveur (non présentes en local)
    final clean = Map<String, dynamic>.from(row);
    clean.remove('user_id');
    clean.remove('updated_at');
    clean.remove('deleted_at');

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
          return http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 20));
        case 'POST':
          return http.post(Uri.parse(url), headers: headers, body: body).timeout(const Duration(seconds: 20));
        case 'PATCH':
          return http.patch(Uri.parse(url), headers: headers, body: body).timeout(const Duration(seconds: 20));
        case 'DELETE':
          return http.delete(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 20));
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
