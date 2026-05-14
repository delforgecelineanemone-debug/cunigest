// ──────────────────────────────────────────────────────────────
// Modèle : Pesée individuelle d'un lapin (V2.4 — Phase 4)
// ──────────────────────────────────────────────────────────────
// Permet de tracer la croissance d'un lapin au fil du temps
// (table pesees_lapin créée en migration v9).
// ──────────────────────────────────────────────────────────────

class PeseeLapin {
  final int? id;
  final int lapinId;
  final String datePesee; // AAAA-MM-JJ
  final double poids;     // kg
  final String? notes;

  const PeseeLapin({
    this.id,
    required this.lapinId,
    required this.datePesee,
    required this.poids,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'lapin_id': lapinId,
        'date_pesee': datePesee,
        'poids': poids,
        'notes': notes,
      };

  factory PeseeLapin.fromMap(Map<String, dynamic> m) => PeseeLapin(
        id: m['id'],
        lapinId: m['lapin_id'],
        datePesee: m['date_pesee'],
        poids: (m['poids'] as num).toDouble(),
        notes: m['notes'],
      );
}
