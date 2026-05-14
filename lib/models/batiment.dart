// ──────────────────────────────────────────────────────────────
// Modèle : Bâtiment (V2.2 — Phase 2 cages)
// ──────────────────────────────────────────────────────────────
// Niveau le plus haut de la hiérarchie d'élevage :
//   Bâtiment → Clapier → Cage → Lapin(s)
// Un bâtiment regroupe plusieurs clapiers (ensembles physiques de cages).
// ──────────────────────────────────────────────────────────────

class Batiment {
  final int? id;
  final String nom;
  final String? adresse;
  final String? notes;
  final String dateCreation;

  Batiment({
    this.id,
    required this.nom,
    this.adresse,
    this.notes,
    String? dateCreation,
  }) : dateCreation =
            dateCreation ?? DateTime.now().toIso8601String().substring(0, 10);

  Map<String, dynamic> toMap() => {
        'id': id,
        'nom': nom,
        'adresse': adresse,
        'notes': notes,
        'date_creation': dateCreation,
      };

  factory Batiment.fromMap(Map<String, dynamic> m) => Batiment(
        id: m['id'] as int?,
        nom: m['nom'] as String,
        adresse: m['adresse'] as String?,
        notes: m['notes'] as String?,
        dateCreation: m['date_creation'] as String,
      );

  Batiment copyWith({
    int? id,
    String? nom,
    String? adresse,
    String? notes,
  }) =>
      Batiment(
        id: id ?? this.id,
        nom: nom ?? this.nom,
        adresse: adresse ?? this.adresse,
        notes: notes ?? this.notes,
        dateCreation: dateCreation,
      );
}
