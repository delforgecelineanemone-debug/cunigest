// ──────────────────────────────────────────────────────────────
// Modèle de données : Stock (Alimentation)
// ──────────────────────────────────────────────────────────────
// Représente un produit en stock dans l'élevage.
// Peut être de l'alimentation (granulés, foin...) ou des médicaments.
//
// Le système d'alertes avertit quand :
// - Le stock passe sous le seuil minimum (quantiteMin)
// - Le produit est expiré (dateExpiration)
// ──────────────────────────────────────────────────────────────

/// Modèle représentant un produit en stock
class Stock {
  final int? id;
  final String produit;         // Nom du produit
  final String typeAliment;     // Catégorie (Granulés, Foin, etc.)
  double quantite;              // Quantité actuelle en stock
  final String unite;           // Unité de mesure (kg, L, sac, etc.)
  final double quantiteMin;     // Seuil d'alerte minimum
  final String? dateEntree;     // Date d'entrée en stock
  final String? dateExpiration; // Date d'expiration
  final String? fournisseur;    // Nom du fournisseur
  final double? coutUnitaire;   // Prix par unité
  final String? notes;

  Stock({
    this.id,
    required this.produit,
    required this.typeAliment,
    required this.quantite,
    required this.unite,
    this.quantiteMin = 0,
    this.dateEntree,
    this.dateExpiration,
    this.fournisseur,
    this.coutUnitaire,
    this.notes,
  });

  /// Convertit en Map pour la base de données
  Map<String, dynamic> toMap() => {
        'id': id,
        'produit': produit,
        'type_aliment': typeAliment,
        'quantite': quantite,
        'unite': unite,
        'quantite_min': quantiteMin,
        'date_entree': dateEntree,
        'date_expiration': dateExpiration,
        'fournisseur': fournisseur,
        'cout_unitaire': coutUnitaire,
        'notes': notes,
      };

  /// Crée un Stock depuis une Map de la base de données
  factory Stock.fromMap(Map<String, dynamic> m) => Stock(
        id: m['id'],
        produit: m['produit'],
        typeAliment: m['type_aliment'],
        quantite: (m['quantite'] as num).toDouble(),
        unite: m['unite'],
        quantiteMin: (m['quantite_min'] as num?)?.toDouble() ?? 0,
        dateEntree: m['date_entree'],
        dateExpiration: m['date_expiration'],
        fournisseur: m['fournisseur'],
        coutUnitaire: m['cout_unitaire'] != null ? (m['cout_unitaire'] as num).toDouble() : null,
        notes: m['notes'],
      );

  /// Crée une copie avec certains champs modifiés
  Stock copyWith({
    int? id,
    String? produit,
    String? typeAliment,
    double? quantite,
    String? unite,
    double? quantiteMin,
    String? dateEntree,
    String? dateExpiration,
    String? fournisseur,
    double? coutUnitaire,
    String? notes,
  }) => Stock(
        id: id ?? this.id,
        produit: produit ?? this.produit,
        typeAliment: typeAliment ?? this.typeAliment,
        quantite: quantite ?? this.quantite,
        unite: unite ?? this.unite,
        quantiteMin: quantiteMin ?? this.quantiteMin,
        dateEntree: dateEntree ?? this.dateEntree,
        dateExpiration: dateExpiration ?? this.dateExpiration,
        fournisseur: fournisseur ?? this.fournisseur,
        coutUnitaire: coutUnitaire ?? this.coutUnitaire,
        notes: notes ?? this.notes,
      );

  /// Vrai si le stock est en dessous du seuil minimum
  bool get estCritique => quantite <= quantiteMin;

  /// Vrai si le produit est expiré
  bool get estExpire {
    if (dateExpiration == null) return false;
    final exp = DateTime.tryParse(dateExpiration!);
    if (exp == null) return false;
    return exp.isBefore(DateTime.now());
  }

  /// Catégories d'aliments disponibles dans les formulaires
  static const List<String> typesAliments = [
    'Granulés',
    'Foin',
    'Paille',
    'Légumes',
    'Complément minéral',
    'Médicament',
    'Autre',
  ];

  /// Unités de mesure disponibles dans les formulaires
  static const List<String> unites = ['kg', 'g', 'L', 'mL', 'botte', 'sac', 'boîte'];
}
