// ──────────────────────────────────────────────────────────────
// Modèle de données : Alerte (Notifications Intelligentes)
// ──────────────────────────────────────────────────────────────
// Représente une notification dans le système d'alertes.
// Les alertes sont générées automatiquement depuis :
// - Le cycle de reproduction (palpation, nid, mise bas)
// - Les rappels de vaccins
// - Les stocks critiques
// - Les routines non complétées
//
// Priorités : critique (🔴), important (🟠), normal (🟢)
// ──────────────────────────────────────────────────────────────

/// Modèle représentant une alerte/notification dans l'application
class Alerte {
  final int? id;
  final String type;            // 'palpation', 'nid', 'mise_bas', 'mamelles_j4|j10|j20', 'pesee_lapereaux', 'sevrage_j21|j28', 'vaccin', 'stock', 'routine', 'motivation'
  final String titre;           // Titre court de l'alerte
  final String? message;        // Message détaillé
  final String priorite;        // 'critique', 'important', 'normal'
  final String dateAlerte;      // Date à laquelle l'alerte doit apparaître
  final bool estLue;            // L'utilisateur a vu l'alerte
  final bool estTraitee;        // L'utilisateur a traité l'alerte
  final int? referenceId;       // ID de l'objet lié (saillie, soin, stock...)
  final String? referenceType;  // Type : 'saillie', 'soin', 'stock', 'lapin'

  Alerte({
    this.id,
    required this.type,
    required this.titre,
    this.message,
    this.priorite = 'normal',
    String? dateAlerte,
    this.estLue = false,
    this.estTraitee = false,
    this.referenceId,
    this.referenceType,
  }) : dateAlerte = dateAlerte ?? DateTime.now().toIso8601String().substring(0, 10);

  /// Convertit en Map pour la base de données
  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'titre': titre,
        'message': message,
        'priorite': priorite,
        'date_alerte': dateAlerte,
        'est_lue': estLue ? 1 : 0,
        'est_traitee': estTraitee ? 1 : 0,
        'reference_id': referenceId,
        'reference_type': referenceType,
      };

  /// Crée une Alerte depuis une Map de la base de données
  factory Alerte.fromMap(Map<String, dynamic> m) => Alerte(
        id: m['id'],
        type: m['type'],
        titre: m['titre'],
        message: m['message'],
        priorite: m['priorite'] ?? 'normal',
        dateAlerte: m['date_alerte'],
        estLue: (m['est_lue'] ?? 0) == 1,
        estTraitee: (m['est_traitee'] ?? 0) == 1,
        referenceId: m['reference_id'],
        referenceType: m['reference_type'],
      );

  /// Icône selon le type d'alerte
  String get typeIcon {
    if (type.startsWith('mamelles')) return '🩺';
    if (type.startsWith('sevrage')) return '🍼';
    if (type.startsWith('sexage')) return '🏷️';
    switch (type) {
      case 'palpation':
        return '🤚';
      case 'nid':
        return '🏠';
      case 'mise_bas':
        return '🐣';
      case 'pesee_lapereaux':
        return '⚖️';
      case 'vaccin':
        return '💉';
      case 'stock':
        return '📦';
      case 'routine':
        return '📋';
      case 'motivation':
        return '💪';
      default:
        return '🔔';
    }
  }

  /// Label de priorité avec couleur
  String get prioriteLabel {
    switch (priorite) {
      case 'critique':
        return '🔴 URGENT';
      case 'important':
        return '🟠 Important';
      default:
        return '🟢 Info';
    }
  }

  /// Vrai si l'alerte est pour aujourd'hui ou avant
  bool get estDue {
    final date = DateTime.tryParse(dateAlerte);
    if (date == null) return false;
    final now = DateTime.now();
    return date.isBefore(DateTime(now.year, now.month, now.day + 1));
  }

  /// Vrai si l'alerte est en retard (date passée et non traitée)
  bool get estEnRetard {
    if (estTraitee) return false;
    final date = DateTime.tryParse(dateAlerte);
    if (date == null) return false;
    final today = DateTime.now();
    return date.isBefore(DateTime(today.year, today.month, today.day));
  }
}
