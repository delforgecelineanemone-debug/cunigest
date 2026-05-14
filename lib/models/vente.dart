// ──────────────────────────────────────────────────────────────
// Modèle de données : Vente
// ──────────────────────────────────────────────────────────────
// Représente la vente d'un ou plusieurs lapins.
// Quand un lapin est vendu, son statut passe automatiquement à 'vendu'.
//
// Types de vente : vivant, abattu, lapereau
// ──────────────────────────────────────────────────────────────

/// Modèle représentant une vente de lapin(s)
class Vente {
  final int? id;
  final int? lapinId;          // ID du lapin vendu (null si lot)
  final int? lotId;            // V2.5 — ID du lot vendu (null si vente individuelle)
  final String dateVente;      // Date de la vente
  final String typeVente;      // 'vivant', 'abattu', 'lapereau'
  final String? acheteur;      // Nom de l'acheteur
  final double prixVente;      // Prix de vente total
  final double? poids;         // Poids au moment de la vente (kg)
  final int quantite;          // Nombre de lapins vendus (1 par défaut)
  final String? notes;

  // Champ de navigation (non stocké en base)
  String? lapinNom;            // Nom affiché du lapin vendu

  Vente({
    this.id,
    this.lapinId,
    this.lotId,
    required this.dateVente,
    required this.typeVente,
    this.acheteur,
    required this.prixVente,
    this.poids,
    this.quantite = 1,
    this.notes,
    this.lapinNom,
  });

  /// Convertit en Map pour la base de données
  Map<String, dynamic> toMap() => {
        'id': id,
        'lapin_id': lapinId,
        'lot_id': lotId,
        'date_vente': dateVente,
        'type_vente': typeVente,
        'acheteur': acheteur,
        'prix_vente': prixVente,
        'poids': poids,
        'quantite': quantite,
        'notes': notes,
      };

  /// Crée une Vente depuis une Map de la base de données
  factory Vente.fromMap(Map<String, dynamic> m) => Vente(
        id: m['id'],
        lapinId: m['lapin_id'],
        lotId: m['lot_id'] as int?,
        dateVente: m['date_vente'],
        typeVente: m['type_vente'],
        acheteur: m['acheteur'],
        prixVente: (m['prix_vente'] as num).toDouble(),
        poids: m['poids'] != null ? (m['poids'] as num).toDouble() : null,
        quantite: m['quantite'] ?? 1,
        notes: m['notes'],
      );

  /// Crée une copie avec certains champs modifiés
  Vente copyWith({
    int? id,
    int? lapinId,
    int? lotId,
    bool clearLot = false,
    String? dateVente,
    String? typeVente,
    String? acheteur,
    double? prixVente,
    double? poids,
    int? quantite,
    String? notes,
  }) => Vente(
        id: id ?? this.id,
        lapinId: lapinId ?? this.lapinId,
        lotId: clearLot ? null : (lotId ?? this.lotId),
        dateVente: dateVente ?? this.dateVente,
        typeVente: typeVente ?? this.typeVente,
        acheteur: acheteur ?? this.acheteur,
        prixVente: prixVente ?? this.prixVente,
        poids: poids ?? this.poids,
        quantite: quantite ?? this.quantite,
        notes: notes ?? this.notes,
        lapinNom: lapinNom,
      );

  /// Affiche le type de vente avec un emoji
  String get typeLabel {
    switch (typeVente) {
      case 'vivant': return '🐇 Vivant';
      case 'abattu': return '🥩 Abattu';
      case 'lapereau': return '🐰 Lapereau';
      default: return typeVente;
    }
  }

  /// Types de vente disponibles dans les formulaires
  static const List<String> typesVente = [
    'vivant',
    'abattu',
    'lapereau',
  ];

  /// Labels affichés pour chaque type de vente
  static const Map<String, String> typesVenteLabels = {
    'vivant': '🐇 Lapin vivant',
    'abattu': '🥩 Lapin abattu',
    'lapereau': '🐰 Lapereau(x)',
  };
}
