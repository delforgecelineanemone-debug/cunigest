// ──────────────────────────────────────────────────────────────
// Modèle : SyncEntry (Synchronisation cloud — V2)
// ──────────────────────────────────────────────────────────────
// Chaque modification locale (insert/update/delete) est ajoutée
// à la file `sync_queue`. Quand une connexion internet est
// disponible, le SyncService pousse les entrées vers le serveur
// (Supabase) puis pull les modifications distantes.
//
// Stratégie de résolution de conflit : "last write wins" basée
// sur le timestamp `updated_at` côté serveur.
// ──────────────────────────────────────────────────────────────

class SyncEntry {
  final int? id;
  final String tableName;        // 'lapins', 'saillies', etc.
  final int rowId;               // ID de la ligne dans la table source
  final String operation;        // 'insert', 'update', 'delete'
  final String payloadJson;      // Snapshot JSON de la ligne au moment de l'opération
  final String createdAt;        // ISO 8601
  final String? syncedAt;        // ISO 8601 — null si pas encore synchronisé
  final String? errorMessage;    // Dernier message d'erreur (debug)
  final int retryCount;

  const SyncEntry({
    this.id,
    required this.tableName,
    required this.rowId,
    required this.operation,
    required this.payloadJson,
    required this.createdAt,
    this.syncedAt,
    this.errorMessage,
    this.retryCount = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'table_name': tableName,
        'row_id': rowId,
        'operation': operation,
        'payload_json': payloadJson,
        'created_at': createdAt,
        'synced_at': syncedAt,
        'error_message': errorMessage,
        'retry_count': retryCount,
      };

  factory SyncEntry.fromMap(Map<String, dynamic> m) => SyncEntry(
        id: m['id'],
        tableName: m['table_name'],
        rowId: m['row_id'],
        operation: m['operation'],
        payloadJson: m['payload_json'],
        createdAt: m['created_at'],
        syncedAt: m['synced_at'],
        errorMessage: m['error_message'],
        retryCount: m['retry_count'] ?? 0,
      );

  SyncEntry copyWith({
    String? syncedAt,
    String? errorMessage,
    int? retryCount,
  }) =>
      SyncEntry(
        id: id,
        tableName: tableName,
        rowId: rowId,
        operation: operation,
        payloadJson: payloadJson,
        createdAt: createdAt,
        syncedAt: syncedAt ?? this.syncedAt,
        errorMessage: errorMessage ?? this.errorMessage,
        retryCount: retryCount ?? this.retryCount,
      );
}

/// Configuration sync + compte cuniculteur unique
///
/// Cette ligne (singleton, id=1) joue 2 rôles :
/// 1. **Compte local** : email + nom + password_hash (pour login offline)
/// 2. **État du lien cloud** : userId + accessToken + refreshToken (Supabase)
///
/// Un compte peut exister localement SANS être lié au cloud (premier
/// lancement sans réseau). Le lien se fait automatiquement quand internet
/// est disponible.
class SyncConfig {
  final bool enabled;              // Par défaut true dès qu'un compte existe
  final String? serverUrl;         // Supabase project URL (config build)
  final String? apiKey;            // Clé publique Supabase (config build)
  final String? userId;            // UUID Supabase une fois lié au cloud
  final String? email;             // Email du compte cuniculteur
  final String? nom;               // Nom affiché (facultatif)
  final String? passwordHash;      // Hash local pour vérifier mot de passe offline
  final String? accessToken;       // JWT Supabase
  final String? refreshToken;      // Pour renouveler l'accessToken
  final String? lastSyncAt;        // Dernière sync réussie (ISO timestamp)

  const SyncConfig({
    this.enabled = true,
    this.serverUrl,
    this.apiKey,
    this.userId,
    this.email,
    this.nom,
    this.passwordHash,
    this.accessToken,
    this.refreshToken,
    this.lastSyncAt,
  });

  /// Le compte local est créé (email + hash présents).
  bool get hasLocalAccount =>
      email != null && email!.isNotEmpty &&
      passwordHash != null && passwordHash!.isNotEmpty;

  /// Le compte est lié au cloud (tokens valides).
  bool get isCloudLinked =>
      accessToken != null && accessToken!.isNotEmpty && userId != null;

  /// Authentifié = lié au cloud (alias pour rétro-compatibilité).
  bool get isAuthenticated => isCloudLinked;

  Map<String, dynamic> toMap() => {
        'id': 1,
        'enabled': enabled ? 1 : 0,
        'server_url': serverUrl,
        'api_key': apiKey,
        'user_id': userId,
        'email': email,
        'nom': nom,
        'password_hash': passwordHash,
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'last_sync_at': lastSyncAt,
      };

  factory SyncConfig.fromMap(Map<String, dynamic> m) => SyncConfig(
        enabled: (m['enabled'] ?? 1) == 1,
        serverUrl: m['server_url'],
        apiKey: m['api_key'],
        userId: m['user_id'],
        email: m['email'],
        nom: m['nom'],
        passwordHash: m['password_hash'],
        accessToken: m['access_token'],
        refreshToken: m['refresh_token'],
        lastSyncAt: m['last_sync_at'],
      );

  SyncConfig copyWith({
    bool? enabled,
    String? serverUrl,
    String? apiKey,
    String? userId,
    String? email,
    String? nom,
    String? passwordHash,
    String? accessToken,
    String? refreshToken,
    String? lastSyncAt,
    bool clearAuth = false,
  }) =>
      SyncConfig(
        enabled: enabled ?? this.enabled,
        serverUrl: serverUrl ?? this.serverUrl,
        apiKey: apiKey ?? this.apiKey,
        userId: clearAuth ? null : (userId ?? this.userId),
        email: email ?? this.email,
        nom: nom ?? this.nom,
        passwordHash: passwordHash ?? this.passwordHash,
        accessToken: clearAuth ? null : (accessToken ?? this.accessToken),
        refreshToken: clearAuth ? null : (refreshToken ?? this.refreshToken),
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      );
}
