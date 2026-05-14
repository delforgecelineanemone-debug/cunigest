// ──────────────────────────────────────────────────────────────
// Modèle : Utilisateur (Multi-utilisateur — V2)
// ──────────────────────────────────────────────────────────────
// Une instance locale peut héberger plusieurs utilisateurs avec
// des rôles distincts :
//
// - admin : accès complet (lapins, repro, santé, ventes, finances)
// - soigneur : accès saisie quotidienne (mises bas, soins) sans
//              accès aux finances ni aux suppressions
//
// L'authentification est PIN local (4-6 chiffres) — pas de mot de
// passe complet ni de compte cloud par défaut.
// ──────────────────────────────────────────────────────────────

class AppUser {
  final int? id;
  final String nom;
  final String role;             // 'admin' ou 'soigneur'
  final String pinHash;          // SHA-256 du PIN (jamais stocker en clair)
  final String dateCreation;
  final String? derniereConnexion;

  const AppUser({
    this.id,
    required this.nom,
    required this.role,
    required this.pinHash,
    required this.dateCreation,
    this.derniereConnexion,
  });

  /// Indique si l'utilisateur peut accéder aux modules financiers
  bool get peutVoirFinances => role == 'admin';

  /// Indique si l'utilisateur peut supprimer des données
  bool get peutSupprimer => role == 'admin';

  /// Indique si l'utilisateur peut modifier les réglages
  bool get peutModifierReglages => role == 'admin';

  /// Libellé du rôle pour l'UI
  String get roleLabel {
    switch (role) {
      case 'admin':
        return '👤 Administrateur';
      case 'soigneur':
        return '🧑‍🌾 Soigneur';
      default:
        return role;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nom': nom,
        'role': role,
        'pin_hash': pinHash,
        'date_creation': dateCreation,
        'derniere_connexion': derniereConnexion,
      };

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        id: m['id'],
        nom: m['nom'],
        role: m['role'],
        pinHash: m['pin_hash'],
        dateCreation: m['date_creation'],
        derniereConnexion: m['derniere_connexion'],
      );

  AppUser copyWith({
    int? id,
    String? nom,
    String? role,
    String? pinHash,
    String? derniereConnexion,
  }) =>
      AppUser(
        id: id ?? this.id,
        nom: nom ?? this.nom,
        role: role ?? this.role,
        pinHash: pinHash ?? this.pinHash,
        dateCreation: dateCreation,
        derniereConnexion: derniereConnexion ?? this.derniereConnexion,
      );
}
