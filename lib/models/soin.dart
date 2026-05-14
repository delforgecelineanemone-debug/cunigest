// ──────────────────────────────────────────────────────────────
// Modèle de données : Soin (Santé & Vaccinations)
// ──────────────────────────────────────────────────────────────
// Représente un soin médical ou une vaccination.
// Peut concerner un lapin spécifique ou tout l'élevage.
//
// Types courants : VHD, Myxomatose, antiparasitaires, etc.
//
// IMPORTANT : `delaiAttenteJours` correspond au temps légal
// avant abattage/vente (résidus de médicaments). Un lapin sous
// délai d'attente NE PEUT PAS être vendu pour la consommation.
// ──────────────────────────────────────────────────────────────

/// Modèle représentant un soin médical ou une vaccination
class Soin {
  final int? id;
  final int? lapinId;          // null = soin collectif (tout l'élevage)
  final String typeSoin;       // Type de soin (voir typesSoins ci-dessous)
  final String dateSoin;       // Date du soin
  String? dateRappel;          // Date de rappel (pour vaccins)
  final String? produit;       // Nom du produit utilisé
  final String? dose;          // Dosage administré
  final String? veterinaire;   // Nom du vétérinaire
  final double? cout;          // Coût du soin en devise
  final int? delaiAttenteJours; // Délai d'attente avant vente/abattage (jours)
  final String? notes;

  // Champ de navigation (non stocké en base)
  String? lapinNom;            // Nom affiché du lapin concerné

  Soin({
    this.id,
    this.lapinId,
    required this.typeSoin,
    required this.dateSoin,
    this.dateRappel,
    this.produit,
    this.dose,
    this.veterinaire,
    this.cout,
    this.delaiAttenteJours,
    this.notes,
    this.lapinNom,
  });

  /// Convertit en Map pour la base de données
  Map<String, dynamic> toMap() => {
        'id': id,
        'lapin_id': lapinId,
        'type_soin': typeSoin,
        'date_soin': dateSoin,
        'date_rappel': dateRappel,
        'produit': produit,
        'dose': dose,
        'veterinaire': veterinaire,
        'cout': cout,
        'delai_attente_jours': delaiAttenteJours,
        'notes': notes,
      };

  /// Crée un Soin depuis une Map de la base de données
  factory Soin.fromMap(Map<String, dynamic> m) => Soin(
        id: m['id'],
        lapinId: m['lapin_id'],
        typeSoin: m['type_soin'],
        dateSoin: m['date_soin'],
        dateRappel: m['date_rappel'],
        produit: m['produit'],
        dose: m['dose'],
        veterinaire: m['veterinaire'],
        cout: m['cout'] != null ? (m['cout'] as num).toDouble() : null,
        delaiAttenteJours: m['delai_attente_jours'],
        notes: m['notes'],
      );

  /// Crée une copie avec certains champs modifiés
  Soin copyWith({
    int? id,
    int? lapinId,
    String? typeSoin,
    String? dateSoin,
    String? dateRappel,
    String? produit,
    String? dose,
    String? veterinaire,
    double? cout,
    int? delaiAttenteJours,
    String? notes,
  }) => Soin(
        id: id ?? this.id,
        lapinId: lapinId ?? this.lapinId,
        typeSoin: typeSoin ?? this.typeSoin,
        dateSoin: dateSoin ?? this.dateSoin,
        dateRappel: dateRappel ?? this.dateRappel,
        produit: produit ?? this.produit,
        dose: dose ?? this.dose,
        veterinaire: veterinaire ?? this.veterinaire,
        cout: cout ?? this.cout,
        delaiAttenteJours: delaiAttenteJours ?? this.delaiAttenteJours,
        notes: notes ?? this.notes,
        lapinNom: lapinNom,
      );

  /// Liste des types de soins disponibles dans les formulaires
  static const List<String> typesSoins = [
    'Vaccination VHD',
    'Vaccination Myxomatose',
    'Vaccination VHD2',
    'Antiparasitaire',
    'Antibiotique',
    'Traitement coccidiose',
    'Traitement gale',
    'Consultation vétérinaire',
    'Pesée',
    'Autre',
  ];

  /// Délais d'attente par défaut (en jours) pour les principaux traitements
  /// Sources : RCP des principaux médicaments cunicoles français
  /// Ces valeurs sont indicatives — vérifier l'AMM réelle du produit utilisé.
  static const Map<String, int> delaisAttenteParDefaut = {
    'Antibiotique': 28,
    'Traitement coccidiose': 5,
    'Traitement gale': 14,
    'Antiparasitaire': 14,
  };

  /// Indique si le rappel est urgent (dans les 7 prochains jours)
  bool get rappelUrgent {
    if (dateRappel == null) return false;
    final rappel = DateTime.tryParse(dateRappel!);
    if (rappel == null) return false;
    return rappel.isBefore(DateTime.now().add(const Duration(days: 7)));
  }

  /// Date de fin du délai d'attente (null si pas de délai)
  DateTime? get finDelaiAttente {
    if (delaiAttenteJours == null || delaiAttenteJours == 0) return null;
    final debut = DateTime.tryParse(dateSoin);
    if (debut == null) return null;
    return debut.add(Duration(days: delaiAttenteJours!));
  }

  /// Indique si le délai d'attente est encore en cours aujourd'hui
  bool get delaiAttenteActif {
    final fin = finDelaiAttente;
    if (fin == null) return false;
    return fin.isAfter(DateTime.now());
  }
}
