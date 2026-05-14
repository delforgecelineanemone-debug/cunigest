// ──────────────────────────────────────────────────────────────
// Modèle : MouvementCage (V2.2 — Phase 2 cages)
// ──────────────────────────────────────────────────────────────
// Trace l'historique des déplacements d'un lapin entre cages.
// Permet la traçabilité sanitaire : si un soucis apparaît dans une cage,
// on peut savoir qui y a séjourné et quand.
//
// `cageOrigineId` peut être NULL (premier placement, lapin externe).
// `cageDestinationId` peut être NULL (sortie : vente, mort, abattage).
// ──────────────────────────────────────────────────────────────

class MouvementCage {
  final int? id;
  final int lapinId;
  final int? cageOrigineId;
  final int? cageDestinationId;
  final String date;        // ISO yyyy-MM-dd
  final String? motif;      // libre : "sevrage", "quarantaine", "vente", etc.
  final String? notes;

  MouvementCage({
    this.id,
    required this.lapinId,
    this.cageOrigineId,
    this.cageDestinationId,
    String? date,
    this.motif,
    this.notes,
  }) : date = date ?? DateTime.now().toIso8601String().substring(0, 10);

  Map<String, dynamic> toMap() => {
        'id': id,
        'lapin_id': lapinId,
        'cage_origine_id': cageOrigineId,
        'cage_destination_id': cageDestinationId,
        'date': date,
        'motif': motif,
        'notes': notes,
      };

  factory MouvementCage.fromMap(Map<String, dynamic> m) => MouvementCage(
        id: m['id'] as int?,
        lapinId: m['lapin_id'] as int,
        cageOrigineId: m['cage_origine_id'] as int?,
        cageDestinationId: m['cage_destination_id'] as int?,
        date: m['date'] as String,
        motif: m['motif'] as String?,
        notes: m['notes'] as String?,
      );
}
