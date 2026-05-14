// ──────────────────────────────────────────────────────────────
// Modèles : Lot d'engraissement, Pesée, Distribution d'aliment
// ──────────────────────────────────────────────────────────────
// Un LOT regroupe plusieurs lapereaux issus d'une ou plusieurs
// portées, suivis ensemble de leur sevrage à la vente.
//
// PESÉES : pesées de contrôle régulières → calcul du GMQ (Gain
// Moyen Quotidien).
//
// DISTRIBUTIONS : aliment distribué au lot → calcul de l'IC
// (Indice de Consommation = aliment / poids produit).
// ──────────────────────────────────────────────────────────────

/// Lot d'engraissement
/// V13 : statut prend désormais 'en_cours', 'individualise' (lapereaux baguer
/// individuellement après sexage J+60), 'termine'. Champ saillieId trace
/// l'origine (auto-création depuis une mise bas).
class Lot {
  final int? id;
  final String code;             // Identifiant lisible (ex: "LT-2026-05-001")
  final String dateCreation;     // Date de création du lot (= date mise bas si auto)
  final String? cage;            // Cage / bande
  final int nombreInitial;       // Nombre de lapereaux à la création
  final double? poidsInitial;    // Poids total initial (kg)
  String statut;                 // 'en_cours', 'individualise', 'termine'
  String? dateFin;               // Date de fin (vente / abattage)
  final String? notes;
  final int? saillieId;          // V13 — saillie d'origine (FK saillies.id)

  Lot({
    this.id,
    required this.code,
    required this.dateCreation,
    this.cage,
    required this.nombreInitial,
    this.poidsInitial,
    this.statut = 'en_cours',
    this.dateFin,
    this.notes,
    this.saillieId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'date_creation': dateCreation,
        'cage': cage,
        'nombre_initial': nombreInitial,
        'poids_initial': poidsInitial,
        'statut': statut,
        'date_fin': dateFin,
        'notes': notes,
        'saillie_id': saillieId,
      };

  factory Lot.fromMap(Map<String, dynamic> m) => Lot(
        id: m['id'],
        code: m['code'],
        dateCreation: m['date_creation'],
        cage: m['cage'],
        nombreInitial: m['nombre_initial'],
        poidsInitial: m['poids_initial'] != null ? (m['poids_initial'] as num).toDouble() : null,
        statut: m['statut'] ?? 'en_cours',
        dateFin: m['date_fin'],
        notes: m['notes'],
        saillieId: m['saillie_id'] as int?,
      );

  Lot copyWith({
    int? id,
    String? code,
    String? dateCreation,
    String? cage,
    int? nombreInitial,
    double? poidsInitial,
    String? statut,
    String? dateFin,
    String? notes,
    int? saillieId,
  }) =>
      Lot(
        id: id ?? this.id,
        code: code ?? this.code,
        dateCreation: dateCreation ?? this.dateCreation,
        cage: cage ?? this.cage,
        nombreInitial: nombreInitial ?? this.nombreInitial,
        poidsInitial: poidsInitial ?? this.poidsInitial,
        statut: statut ?? this.statut,
        dateFin: dateFin ?? this.dateFin,
        notes: notes ?? this.notes,
        saillieId: saillieId ?? this.saillieId,
      );
}

/// Pesée de contrôle d'un lot
class Pesee {
  final int? id;
  final int lotId;
  final String datePesee;
  final double poidsTotal;       // kg
  final int nombre;              // Lapereaux pesés
  final String? notes;

  Pesee({
    this.id,
    required this.lotId,
    required this.datePesee,
    required this.poidsTotal,
    required this.nombre,
    this.notes,
  });

  /// Poids moyen par lapereau (kg)
  double get poidsMoyen => nombre > 0 ? poidsTotal / nombre : 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'lot_id': lotId,
        'date_pesee': datePesee,
        'poids_total': poidsTotal,
        'nombre': nombre,
        'notes': notes,
      };

  factory Pesee.fromMap(Map<String, dynamic> m) => Pesee(
        id: m['id'],
        lotId: m['lot_id'],
        datePesee: m['date_pesee'],
        poidsTotal: (m['poids_total'] as num).toDouble(),
        nombre: m['nombre'],
        notes: m['notes'],
      );
}

/// Distribution d'aliment à un lot (consommation)
class DistributionAliment {
  final int? id;
  final int lotId;
  final int? stockId;            // Référence au stock consommé (peut être null si saisie manuelle)
  final String dateDistribution;
  final double quantiteKg;
  final String? notes;

  DistributionAliment({
    this.id,
    required this.lotId,
    this.stockId,
    required this.dateDistribution,
    required this.quantiteKg,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'lot_id': lotId,
        'stock_id': stockId,
        'date_distribution': dateDistribution,
        'quantite_kg': quantiteKg,
        'notes': notes,
      };

  factory DistributionAliment.fromMap(Map<String, dynamic> m) => DistributionAliment(
        id: m['id'],
        lotId: m['lot_id'],
        stockId: m['stock_id'],
        dateDistribution: m['date_distribution'],
        quantiteKg: (m['quantite_kg'] as num).toDouble(),
        notes: m['notes'],
      );
}

/// Statistiques calculées d'un lot
class LotStats {
  final int nombreActuel;        // Estimation = nombreInitial - mortalité
  final double? poidsActuel;     // Dernier poids total connu
  final double? gmq;             // Gain Moyen Quotidien (g/jour/lapereau)
  final double? ic;              // Indice de Consommation (kg aliment / kg poids vif produit)
  final double alimentTotalKg;   // Total aliment consommé
  final int joursElevage;        // Jours depuis la création du lot

  const LotStats({
    required this.nombreActuel,
    this.poidsActuel,
    this.gmq,
    this.ic,
    required this.alimentTotalKg,
    required this.joursElevage,
  });
}
