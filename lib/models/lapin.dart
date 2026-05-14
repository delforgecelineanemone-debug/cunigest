// ──────────────────────────────────────────────────────────────
// Modèle de données : Lapin
// ──────────────────────────────────────────────────────────────
// Représente un lapin individuel dans l'élevage.
// Chaque lapin a un numéro de bague unique (son identifiant physique),
// et peut avoir un nom, une race, un poids, etc.
//
// Statuts possibles : actif, vendu, mort, sevrage, quarantaine
// Généalogie : pere_id / mere_id pointent vers d'autres lapins
// ──────────────────────────────────────────────────────────────

/// Modèle représentant un lapin dans l'élevage
class Lapin {
  final int? id;                // Identifiant unique en base de données
  final String numeroBague;     // Numéro de bague (tatouage) — UNIQUE
  final String? nom;            // Nom du lapin (optionnel)
  final String sexe;            // 'male' ou 'femelle'
  final String? race;           // Race (Néo-Zélandais, Californien, etc.)
  final String? dateNaissance;  // Date de naissance au format ISO (AAAA-MM-JJ)
  double? poids;                // Poids en kg
  final String? couleur;        // Couleur du pelage
  String statut;                // Statut : 'actif', 'vendu', 'mort', 'sevrage', 'quarantaine'
  final int? cageId;            // FK → cages.id (V2.2)
  final String? cageLegacy;     // Ancien champ texte libre (V2.1 et avant)
  final String? photoPath;      // Chemin local de la photo (V2.2, optionnel)
  final String? notes;          // Notes libres
  final int? pereId;            // ID du père (lapin mâle) — généalogie
  final int? mereId;            // ID de la mère (lapine) — généalogie
  final double? prixAchat;      // V2.5 — Prix d'achat (reproducteurs achetés)
  final String? destination;    // V14 — Sortie de ferme : 'vendu', 'consomme', 'reproducteur', 'autre' (null = en cours)
  final String dateCreation;    // Date d'ajout dans l'application

  Lapin({
    this.id,
    required this.numeroBague,
    this.nom,
    required this.sexe,
    this.race,
    this.dateNaissance,
    this.poids,
    this.couleur,
    this.statut = 'actif',
    this.cageId,
    this.cageLegacy,
    this.photoPath,
    this.notes,
    this.pereId,
    this.mereId,
    this.prixAchat,
    this.destination,
    String? dateCreation,
  }) : dateCreation = dateCreation ?? DateTime.now().toIso8601String().substring(0, 10);

  /// Convertit le lapin en Map pour la base de données
  Map<String, dynamic> toMap() => {
        'id': id,
        'numero_bague': numeroBague,
        'nom': nom,
        'sexe': sexe,
        'race': race,
        'date_naissance': dateNaissance,
        'poids': poids,
        'couleur': couleur,
        'statut': statut,
        'cage_id': cageId,
        'cage': cageLegacy,
        'photo_path': photoPath,
        'notes': notes,
        'pere_id': pereId,
        'mere_id': mereId,
        'prix_achat': prixAchat,
        'destination': destination,
        'date_creation': dateCreation,
      };

  /// Crée un Lapin à partir d'une Map de la base de données
  factory Lapin.fromMap(Map<String, dynamic> m) => Lapin(
        id: m['id'],
        numeroBague: m['numero_bague'],
        nom: m['nom'],
        sexe: m['sexe'],
        race: m['race'],
        dateNaissance: m['date_naissance'],
        poids: m['poids'] != null ? (m['poids'] as num).toDouble() : null,
        couleur: m['couleur'],
        statut: m['statut'] ?? 'actif',
        cageId: m['cage_id'] as int?,
        cageLegacy: m['cage'] as String?,
        photoPath: m['photo_path'] as String?,
        notes: m['notes'],
        pereId: m['pere_id'],
        mereId: m['mere_id'],
        prixAchat: m['prix_achat'] != null
            ? (m['prix_achat'] as num).toDouble()
            : null,
        destination: m['destination'] as String?,
        dateCreation: m['date_creation'],
      );

  /// Crée une copie du lapin avec certains champs modifiés
  Lapin copyWith({
    int? id,
    String? numeroBague,
    String? nom,
    String? sexe,
    String? race,
    String? dateNaissance,
    double? poids,
    String? couleur,
    String? statut,
    int? cageId,
    bool clearCageId = false,
    String? cageLegacy,
    String? photoPath,
    bool clearPhoto = false,
    String? notes,
    int? pereId,
    int? mereId,
    double? prixAchat,
    bool clearPrixAchat = false,
    String? destination,
    bool clearDestination = false,
  }) => Lapin(
        id: id ?? this.id,
        numeroBague: numeroBague ?? this.numeroBague,
        nom: nom ?? this.nom,
        sexe: sexe ?? this.sexe,
        race: race ?? this.race,
        dateNaissance: dateNaissance ?? this.dateNaissance,
        poids: poids ?? this.poids,
        couleur: couleur ?? this.couleur,
        statut: statut ?? this.statut,
        cageId: clearCageId ? null : (cageId ?? this.cageId),
        cageLegacy: cageLegacy ?? this.cageLegacy,
        photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
        notes: notes ?? this.notes,
        pereId: pereId ?? this.pereId,
        mereId: mereId ?? this.mereId,
        prixAchat: clearPrixAchat ? null : (prixAchat ?? this.prixAchat),
        destination: clearDestination ? null : (destination ?? this.destination),
        dateCreation: dateCreation,
      );

  /// Alias rétrocompatible : ancien champ texte libre `cage` (V2.1).
  /// Les écrans existants peuvent encore lire/écrire via ce nom.
  /// Phase 2C : à terme tout migrera vers `cageId` (FK cages.id).
  String? get cage => cageLegacy;

  /// Affiche le nom du lapin, ou son numéro de bague s'il n'a pas de nom
  String get displayName => nom != null && nom!.isNotEmpty ? nom! : numeroBague;

  /// Affiche le sexe avec un symbole : ♂ Mâle ou ♀ Femelle
  String get sexeLabel => sexe == 'male' ? '♂ Mâle' : '♀ Femelle';

  /// Libellé de la destination (V14 — sortie de ferme)
  String get destinationLabel {
    switch (destination) {
      case 'vendu': return '💰 Vendu';
      case 'consomme': return '🍴 Auto-consommé';
      case 'reproducteur': return '⭐ Reproducteur sélectionné';
      case 'autre': return '📦 Autre';
      default: return '—';
    }
  }

  /// Affiche le statut en français
  String get statutLabel {
    switch (statut) {
      case 'actif': return 'Actif';
      case 'vendu': return 'Vendu';
      case 'mort': return 'Mort';
      case 'sevrage': return 'Sevrage';
      case 'quarantaine': return 'Quarantaine';
      default: return statut;
    }
  }

  /// Calcule l'âge du lapin en jours (null si date de naissance inconnue)
  int? get ageEnJours {
    if (dateNaissance == null) return null;
    final naissance = DateTime.tryParse(dateNaissance!);
    if (naissance == null) return null;
    return DateTime.now().difference(naissance).inDays;
  }

  /// Affiche l'âge de façon lisible : "45 jours", "3 mois", "1 an(s) 2 mois"
  /// Utilise 30.44 jours/mois et 365.25 jours/an (plus précis)
  String get ageDisplay {
    final j = ageEnJours;
    if (j == null) return 'Inconnu';
    if (j < 30) return '$j jours';
    if (j < 365) return '${(j / 30.44).floor()} mois';
    final ans = (j / 365.25).floor();
    final moisRestants = ((j - ans * 365.25) / 30.44).floor();
    return '$ans an${ans > 1 ? "s" : ""}${moisRestants > 0 ? " $moisRestants mois" : ""}';
  }
}
