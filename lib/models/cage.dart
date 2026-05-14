// ──────────────────────────────────────────────────────────────
// Modèle : Cage (V2.2 — Phase 2 cages)
// ──────────────────────────────────────────────────────────────
// Unité physique abritant 0 à N lapins (capacité définie par l'éleveur).
// Identifiée par un numéro UNIQUE saisi librement (ex : "C4B1", "A-12").
//
// Statuts possibles : vide, occupee, gestante, allaitement, sevrage,
// quarantaine, desinfection, maintenance.
// ──────────────────────────────────────────────────────────────

const List<String> kCageStatuts = [
  'vide',
  'occupee',
  'pleine',
  'gestante',
  'allaitement',
  'sevrage',
  'quarantaine',
  'desinfection',
  'maintenance',
];

class Cage {
  final int? id;
  final String numero;          // identifiant physique (UNIQUE) ex : "C4B1"
  final int clapierId;
  final int capaciteMax;        // 0 ou N lapins maximum
  final String statut;          // voir kCageStatuts
  final String? notes;
  final String dateCreation;

  Cage({
    this.id,
    required this.numero,
    required this.clapierId,
    this.capaciteMax = 1,
    this.statut = 'vide',
    this.notes,
    String? dateCreation,
  }) : dateCreation =
            dateCreation ?? DateTime.now().toIso8601String().substring(0, 10);

  Map<String, dynamic> toMap() => {
        'id': id,
        'numero': numero,
        'clapier_id': clapierId,
        'capacite_max': capaciteMax,
        'statut': statut,
        'notes': notes,
        'date_creation': dateCreation,
      };

  factory Cage.fromMap(Map<String, dynamic> m) => Cage(
        id: m['id'] as int?,
        numero: m['numero'] as String,
        clapierId: m['clapier_id'] as int,
        capaciteMax: (m['capacite_max'] as int?) ?? 1,
        statut: (m['statut'] as String?) ?? 'vide',
        notes: m['notes'] as String?,
        dateCreation: m['date_creation'] as String,
      );

  Cage copyWith({
    int? id,
    String? numero,
    int? clapierId,
    int? capaciteMax,
    String? statut,
    String? notes,
  }) =>
      Cage(
        id: id ?? this.id,
        numero: numero ?? this.numero,
        clapierId: clapierId ?? this.clapierId,
        capaciteMax: capaciteMax ?? this.capaciteMax,
        statut: statut ?? this.statut,
        notes: notes ?? this.notes,
        dateCreation: dateCreation,
      );

  /// Libellé humain du statut.
  String get statutLabel => cageStatutLabel(statut);

  /// Statuts "spéciaux" qui restent renseignés manuellement par l'éleveur.
  /// Les statuts automatiques (`vide`, `occupee`, `pleine`) sont calculés
  /// à partir de l'occupation réelle.
  static const Set<String> statutsSpeciaux = {
    'gestante',
    'allaitement',
    'sevrage',
    'quarantaine',
    'desinfection',
    'maintenance',
  };

  /// True quand le statut courant est un état manuel (gestation, quarantaine…)
  bool get aStatutSpecial => statutsSpeciaux.contains(statut);

  /// Statut effectif à afficher pour [occupants] lapins (V2.5 — auto B4).
  /// - Statut spécial conservé tel quel (priorité éleveur)
  /// - Sinon : vide / occupee / pleine selon occupation
  String statutEffectif(int occupants) {
    if (aStatutSpecial) return statut;
    if (occupants <= 0) return 'vide';
    if (capaciteMax > 0 && occupants >= capaciteMax) return 'pleine';
    return 'occupee';
  }

  /// Charge utile QR : `cunigest:cage:<id>:<numero>`
  String? qrPayload() => id == null ? null : 'cunigest:cage:$id:$numero';
}

/// Libellé FR pour un statut de cage.
String cageStatutLabel(String s) {
  switch (s) {
    case 'vide':
      return 'Vide';
    case 'occupee':
      return 'Occupée';
    case 'pleine':
      return 'Pleine';
    case 'gestante':
      return 'Gestante';
    case 'allaitement':
      return 'Allaitement';
    case 'sevrage':
      return 'Sevrage';
    case 'quarantaine':
      return 'Quarantaine';
    case 'desinfection':
      return 'Désinfection';
    case 'maintenance':
      return 'Maintenance';
    default:
      return s;
  }
}
