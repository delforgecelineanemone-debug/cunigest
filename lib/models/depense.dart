// ──────────────────────────────────────────────────────────────
// Modèle : Dépense (V2.4 — Phase 4 — module Finances)
// ──────────────────────────────────────────────────────────────
// Représente une sortie d'argent dans l'élevage. Catégorisée
// pour le calcul du coût de production et le bilan financier.
// ──────────────────────────────────────────────────────────────

/// Catégories de dépense supportées
const kDepenseCategories = [
  'aliment',
  'soins',
  'materiel',
  'eau',
  'electricite',
  'reproducteur',
  'transport',
  'autre',
];

String depenseCategorieLabel(String c) => switch (c) {
      'aliment' => '🌾 Aliment',
      'soins' => '💉 Soins / Vétérinaire',
      'materiel' => '🔧 Matériel',
      'eau' => '💧 Eau',
      'electricite' => '⚡ Électricité',
      'reproducteur' => '🐇 Achat reproducteur',
      'transport' => '🚚 Transport',
      _ => '📦 Autre',
    };

class Depense {
  final int? id;
  final String dateDepense; // AAAA-MM-JJ
  final String categorie;
  final double montant;
  final String? description;
  final String? notes;
  final int? lotId;        // V2.5 — imputation directe à un lot
  final int? lapinId;      // V2.5 — imputation directe à un lapin (reproducteur)
  final String dateCreation;

  Depense({
    this.id,
    required this.dateDepense,
    required this.categorie,
    required this.montant,
    this.description,
    this.notes,
    this.lotId,
    this.lapinId,
    String? dateCreation,
  }) : dateCreation = dateCreation ??
            DateTime.now().toIso8601String().substring(0, 10);

  Map<String, dynamic> toMap() => {
        'id': id,
        'date_depense': dateDepense,
        'categorie': categorie,
        'montant': montant,
        'description': description,
        'notes': notes,
        'lot_id': lotId,
        'lapin_id': lapinId,
        'date_creation': dateCreation,
      };

  factory Depense.fromMap(Map<String, dynamic> m) => Depense(
        id: m['id'],
        dateDepense: m['date_depense'],
        categorie: m['categorie'],
        montant: (m['montant'] as num).toDouble(),
        description: m['description'],
        notes: m['notes'],
        lotId: m['lot_id'] as int?,
        lapinId: m['lapin_id'] as int?,
        dateCreation: m['date_creation'],
      );

  Depense copyWith({
    String? dateDepense,
    String? categorie,
    double? montant,
    String? description,
    String? notes,
    int? lotId,
    int? lapinId,
    bool clearLot = false,
    bool clearLapin = false,
  }) =>
      Depense(
        id: id,
        dateDepense: dateDepense ?? this.dateDepense,
        categorie: categorie ?? this.categorie,
        montant: montant ?? this.montant,
        description: description ?? this.description,
        notes: notes ?? this.notes,
        lotId: clearLot ? null : (lotId ?? this.lotId),
        lapinId: clearLapin ? null : (lapinId ?? this.lapinId),
        dateCreation: dateCreation,
      );
}
