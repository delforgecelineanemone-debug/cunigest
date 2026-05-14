// ──────────────────────────────────────────────────────────────
// Modèle : Clapier (V2.2 — Phase 2 cages)
// ──────────────────────────────────────────────────────────────
// Un clapier est un ensemble physique de cages, situé dans un bâtiment.
// Exemple : « Clapier reproducteurs A », « Batterie engraissement Nord ».
// ──────────────────────────────────────────────────────────────

class Clapier {
  final int? id;
  final String nom;
  final int batimentId;
  final String? notes;
  final String dateCreation;

  Clapier({
    this.id,
    required this.nom,
    required this.batimentId,
    this.notes,
    String? dateCreation,
  }) : dateCreation =
            dateCreation ?? DateTime.now().toIso8601String().substring(0, 10);

  Map<String, dynamic> toMap() => {
        'id': id,
        'nom': nom,
        'batiment_id': batimentId,
        'notes': notes,
        'date_creation': dateCreation,
      };

  factory Clapier.fromMap(Map<String, dynamic> m) => Clapier(
        id: m['id'] as int?,
        nom: m['nom'] as String,
        batimentId: m['batiment_id'] as int,
        notes: m['notes'] as String?,
        dateCreation: m['date_creation'] as String,
      );

  Clapier copyWith({
    int? id,
    String? nom,
    int? batimentId,
    String? notes,
  }) =>
      Clapier(
        id: id ?? this.id,
        nom: nom ?? this.nom,
        batimentId: batimentId ?? this.batimentId,
        notes: notes ?? this.notes,
        dateCreation: dateCreation,
      );
}
