// ──────────────────────────────────────────────────────────────
// Modèle de données : Tâche Quotidienne (Système de Routines)
// ──────────────────────────────────────────────────────────────
// Représente une tâche à effectuer dans l'élevage.
// Les tâches peuvent être :
// - Automatiques (générées par le système : palpation, mise bas...)
// - Manuelles (ajoutées par l'éleveur : nettoyage, observation...)
//
// Chaque tâche a une priorité : critique, important, normal
// et une récurrence : quotidien, hebdomadaire, mensuel, ponctuel
// ──────────────────────────────────────────────────────────────

/// Statuts possibles d'une tâche (V2.4 — Phase 4 ; V2.5 ajoute 'reporte')
const kTacheStatuts = ['en_attente', 'en_cours', 'fait', 'annule', 'reporte'];

String tacheStatutLabel(String s) => switch (s) {
      'en_cours' => '🟡 En cours',
      'fait' => '✅ Fait',
      'annule' => '⛔ Annulée',
      'reporte' => '⏸️ Reportée',
      _ => '⏳ En attente',
    };

/// Modèle représentant une tâche dans le système de routines
class Tache {
  final int? id;
  final String titre;            // Titre court de la tâche
  final String? description;     // Description détaillée (optionnel)
  final String categorie;        // 'nourriture', 'eau', 'nettoyage', 'sante', 'reproduction', 'observation', 'custom'
  final String priorite;         // 'critique', 'important', 'normal'
  final String recurrence;       // 'quotidien', 'hebdomadaire', 'mensuel', 'ponctuel'
  final String? heureRappel;     // Heure de rappel HH:MM (optionnel)
  final bool estActive;          // Tâche active ou désactivée
  final bool estSysteme;         // true = générée automatiquement, false = créée par l'éleveur
  final int? referenceId;        // ID lié (saillie_id, lapin_id, etc.)
  final String? referenceType;   // Type de référence ('saillie', 'lapin', 'soin')
  final int points;              // Points gagnés quand complétée
  final String dateCreation;
  final String? dateEcheance;    // V2.4 — Date d'échéance (surtout 'ponctuel')
  final String statut;           // V2.4 — 'en_attente', 'en_cours', 'fait', 'annule'
  final String? exceptions;      // V2.4 — Dates AAAA-MM-JJ exclues, séparées par ','

  Tache({
    this.id,
    required this.titre,
    this.description,
    required this.categorie,
    this.priorite = 'normal',
    this.recurrence = 'quotidien',
    this.heureRappel,
    this.estActive = true,
    this.estSysteme = false,
    this.referenceId,
    this.referenceType,
    int? points,
    String? dateCreation,
    this.dateEcheance,
    this.statut = 'en_attente',
    this.exceptions,
  })  : points = points ?? _pointsParDefaut(priorite),
        dateCreation = dateCreation ?? DateTime.now().toIso8601String().substring(0, 10);

  /// Liste des dates d'exception (parsée depuis la chaîne CSV).
  List<String> get exceptionsList =>
      (exceptions == null || exceptions!.isEmpty)
          ? const []
          : exceptions!.split(',').map((s) => s.trim()).toList();

  /// Points par défaut selon la priorité
  static int _pointsParDefaut(String priorite) {
    switch (priorite) {
      case 'critique':
        return 30;
      case 'important':
        return 20;
      default:
        return 10;
    }
  }

  /// Convertit en Map pour la base de données
  Map<String, dynamic> toMap() => {
        'id': id,
        'titre': titre,
        'description': description,
        'categorie': categorie,
        'priorite': priorite,
        'recurrence': recurrence,
        'heure_rappel': heureRappel,
        'est_active': estActive ? 1 : 0,
        'est_systeme': estSysteme ? 1 : 0,
        'reference_id': referenceId,
        'reference_type': referenceType,
        'points': points,
        'date_creation': dateCreation,
        'date_echeance': dateEcheance,
        'statut': statut,
        'exceptions': exceptions,
      };

  /// Crée une Tache depuis une Map de la base de données
  factory Tache.fromMap(Map<String, dynamic> m) => Tache(
        id: m['id'],
        titre: m['titre'],
        description: m['description'],
        categorie: m['categorie'],
        priorite: m['priorite'] ?? 'normal',
        recurrence: m['recurrence'] ?? 'quotidien',
        heureRappel: m['heure_rappel'],
        estActive: (m['est_active'] ?? 1) == 1,
        estSysteme: (m['est_systeme'] ?? 0) == 1,
        referenceId: m['reference_id'],
        referenceType: m['reference_type'],
        points: m['points'] ?? 10,
        dateCreation: m['date_creation'],
        dateEcheance: m['date_echeance'],
        statut: m['statut'] ?? 'en_attente',
        exceptions: m['exceptions'],
      );

  Tache copyWith({
    String? titre,
    String? description,
    String? categorie,
    String? priorite,
    String? recurrence,
    String? heureRappel,
    bool? estActive,
    int? points,
    String? dateEcheance,
    String? statut,
    String? exceptions,
  }) =>
      Tache(
        id: id,
        titre: titre ?? this.titre,
        description: description ?? this.description,
        categorie: categorie ?? this.categorie,
        priorite: priorite ?? this.priorite,
        recurrence: recurrence ?? this.recurrence,
        heureRappel: heureRappel ?? this.heureRappel,
        estActive: estActive ?? this.estActive,
        estSysteme: estSysteme,
        referenceId: referenceId,
        referenceType: referenceType,
        points: points ?? this.points,
        dateCreation: dateCreation,
        dateEcheance: dateEcheance ?? this.dateEcheance,
        statut: statut ?? this.statut,
        exceptions: exceptions ?? this.exceptions,
      );

  /// Icône emoji selon la catégorie
  String get categorieIcon {
    switch (categorie) {
      case 'nourriture':
        return '🌾';
      case 'eau':
        return '💧';
      case 'nettoyage':
        return '🧹';
      case 'sante':
        return '💉';
      case 'reproduction':
        return '❤️';
      case 'observation':
        return '👀';
      case 'custom':
        return '📝';
      default:
        return '📋';
    }
  }

  /// Couleur selon la priorité
  String get prioriteLabel {
    switch (priorite) {
      case 'critique':
        return '🔴 Critique';
      case 'important':
        return '🟠 Important';
      default:
        return '🟢 Normal';
    }
  }

  /// Catégories disponibles pour les formulaires
  static const List<String> categories = [
    'nourriture',
    'eau',
    'nettoyage',
    'sante',
    'reproduction',
    'observation',
    'custom',
  ];

  /// Labels des catégories pour l'affichage
  static const Map<String, String> categorieLabels = {
    'nourriture': '🌾 Nourriture',
    'eau': '💧 Eau',
    'nettoyage': '🧹 Nettoyage',
    'sante': '💉 Santé',
    'reproduction': '❤️ Reproduction',
    'observation': '👀 Observation',
    'custom': '📝 Personnalisée',
  };

  /// Labels des récurrences
  static const Map<String, String> recurrenceLabels = {
    'quotidien': 'Tous les jours',
    'hebdomadaire': 'Chaque semaine',
    'mensuel': 'Chaque mois',
    'ponctuel': 'Une seule fois',
  };
}

/// Modèle représentant la complétion d'une tâche (historique)
class Completion {
  final int? id;
  final int tacheId;
  final String dateCompletion;    // AAAA-MM-JJ
  final String? heureCompletion;  // HH:MM
  final String? notes;

  Completion({
    this.id,
    required this.tacheId,
    String? dateCompletion,
    this.heureCompletion,
    this.notes,
  }) : dateCompletion = dateCompletion ?? DateTime.now().toIso8601String().substring(0, 10);

  Map<String, dynamic> toMap() => {
        'id': id,
        'tache_id': tacheId,
        'date_completion': dateCompletion,
        'heure_completion': heureCompletion,
        'notes': notes,
      };

  factory Completion.fromMap(Map<String, dynamic> m) => Completion(
        id: m['id'],
        tacheId: m['tache_id'],
        dateCompletion: m['date_completion'],
        heureCompletion: m['heure_completion'],
        notes: m['notes'],
      );
}
