// ──────────────────────────────────────────────────────────────
// Modèle de données : Saillie (Reproduction)
// ──────────────────────────────────────────────────────────────
// Représente un accouplement entre une femelle (mère) et un mâle (père).
// La gestation d'une lapine dure environ 31 jours.
//
// Cycle de vie d'une saillie :
// en_attente → mise_bas → sevrage → termine
//
// Statistiques disponibles :
// - Taux de fertilité = saillies positives / saillies totales
// - Prolificité moyenne = moyenne des nb_vivants
// - Mortalité pré-sevrage = (nb_vivants - nb_sevres) / nb_vivants
// ──────────────────────────────────────────────────────────────

/// Modèle représentant une saillie (accouplement)
class Saillie {
  final int? id;
  final int mereId;              // ID de la mère (femelle)
  final int pereId;              // ID du père (mâle)
  final String dateSaillie;      // Date de l'accouplement
  String? dateMiseBasPrevue;     // Date prévue de la mise bas (saillie + 31 jours)
  String? dateMiseBasReelle;     // Date réelle de la mise bas
  int? nbNes;                    // Nombre de lapereaux nés au total
  int? nbVivants;                // Nombre de lapereaux nés vivants
  int? nbMorts;                  // Nombre de lapereaux nés morts
  int? nbSevres;                 // Nombre de lapereaux sevrés
  String? dateSevrage;           // Date du sevrage
  double? poidsSevrageTotal;     // Poids total du lot au sevrage (kg)
  String statut;                 // 'en_attente', 'mise_bas', 'sevrage', 'termine', 'echec'
  bool palpationPositive;        // true = gestation confirmée, false = pas encore palpé/échec
  final int? nbChevauchements;   // V14 — nb de chevauchements réussis à J0
  final String? etatNid;         // V14 — observation J+28 (ex. "Prêt", "Litière manquante")
  final String? notes;
  final int? lotId;              // V13 — lot auto-créé depuis la mise bas (FK lots.id)

  // Champs de navigation (non stockés en base, remplis à la lecture)
  String? mereNom;               // Nom affiché de la mère
  String? pereNom;               // Nom affiché du père

  Saillie({
    this.id,
    required this.mereId,
    required this.pereId,
    required this.dateSaillie,
    this.dateMiseBasPrevue,
    this.dateMiseBasReelle,
    this.nbNes,
    this.nbVivants,
    this.nbMorts,
    this.nbSevres,
    this.dateSevrage,
    this.poidsSevrageTotal,
    this.statut = 'en_attente',
    this.palpationPositive = false,
    this.nbChevauchements,
    this.etatNid,
    this.notes,
    this.lotId,
    this.mereNom,
    this.pereNom,
  });

  /// Convertit en Map pour la base de données
  Map<String, dynamic> toMap() => {
        'id': id,
        'mere_id': mereId,
        'pere_id': pereId,
        'date_saillie': dateSaillie,
        'date_mise_bas_prevue': dateMiseBasPrevue,
        'date_mise_bas_reelle': dateMiseBasReelle,
        'nb_nes': nbNes,
        'nb_vivants': nbVivants,
        'nb_morts': nbMorts,
        'nb_sevres': nbSevres,
        'date_sevrage': dateSevrage,
        'poids_sevrage_total': poidsSevrageTotal,
        'statut': statut,
        'palpation_positive': palpationPositive ? 1 : 0,
        'nb_chevauchements': nbChevauchements,
        'etat_nid': etatNid,
        'notes': notes,
        'lot_id': lotId,
      };

  /// Crée une Saillie depuis une Map de la base de données
  factory Saillie.fromMap(Map<String, dynamic> m) => Saillie(
        id: m['id'],
        mereId: m['mere_id'],
        pereId: m['pere_id'],
        dateSaillie: m['date_saillie'],
        dateMiseBasPrevue: m['date_mise_bas_prevue'],
        dateMiseBasReelle: m['date_mise_bas_reelle'],
        nbNes: m['nb_nes'],
        nbVivants: m['nb_vivants'],
        nbMorts: m['nb_morts'],
        nbSevres: m['nb_sevres'],
        dateSevrage: m['date_sevrage'],
        poidsSevrageTotal: m['poids_sevrage_total'] != null
            ? (m['poids_sevrage_total'] as num).toDouble()
            : null,
        statut: m['statut'] ?? 'en_attente',
        palpationPositive: (m['palpation_positive'] ?? 0) == 1,
        nbChevauchements: m['nb_chevauchements'] as int?,
        etatNid: m['etat_nid'] as String?,
        notes: m['notes'],
        lotId: m['lot_id'] as int?,
      );

  /// Crée une copie avec certains champs modifiés
  Saillie copyWith({
    int? id,
    int? mereId,
    int? pereId,
    String? dateSaillie,
    String? dateMiseBasPrevue,
    String? dateMiseBasReelle,
    int? nbNes,
    int? nbVivants,
    int? nbMorts,
    int? nbSevres,
    String? dateSevrage,
    double? poidsSevrageTotal,
    String? statut,
    bool? palpationPositive,
    int? nbChevauchements,
    String? etatNid,
    String? notes,
    int? lotId,
  }) => Saillie(
        id: id ?? this.id,
        mereId: mereId ?? this.mereId,
        pereId: pereId ?? this.pereId,
        dateSaillie: dateSaillie ?? this.dateSaillie,
        dateMiseBasPrevue: dateMiseBasPrevue ?? this.dateMiseBasPrevue,
        dateMiseBasReelle: dateMiseBasReelle ?? this.dateMiseBasReelle,
        nbNes: nbNes ?? this.nbNes,
        nbVivants: nbVivants ?? this.nbVivants,
        nbMorts: nbMorts ?? this.nbMorts,
        nbSevres: nbSevres ?? this.nbSevres,
        dateSevrage: dateSevrage ?? this.dateSevrage,
        poidsSevrageTotal: poidsSevrageTotal ?? this.poidsSevrageTotal,
        statut: statut ?? this.statut,
        palpationPositive: palpationPositive ?? this.palpationPositive,
        nbChevauchements: nbChevauchements ?? this.nbChevauchements,
        etatNid: etatNid ?? this.etatNid,
        notes: notes ?? this.notes,
        lotId: lotId ?? this.lotId,
        mereNom: mereNom,
        pereNom: pereNom,
      );

  /// Affiche le statut avec un emoji
  String get statutLabel {
    switch (statut) {
      case 'en_attente': return '⏳ En attente';
      case 'mise_bas': return '🐣 Mise bas';
      case 'sevrage': return '🍼 Sevrage';
      case 'termine': return '✅ Terminé';
      case 'echec': return '❌ Échec';
      default: return statut;
    }
  }

  /// Calcule le nombre de jours restants avant la mise bas prévue
  /// Retourne un nombre négatif si la date est dépassée
  int? get joursRestants {
    if (dateMiseBasPrevue == null) return null;
    final prevue = DateTime.tryParse(dateMiseBasPrevue!);
    if (prevue == null) return null;
    return prevue.difference(DateTime.now()).inDays;
  }

  /// Mortalité pré-sevrage en pourcentage (0-100), ou null si données insuffisantes
  double? get mortalitePreSevrage {
    if (nbVivants == null || nbVivants == 0 || nbSevres == null) return null;
    final perdus = nbVivants! - nbSevres!;
    if (perdus < 0) return 0.0;
    return (perdus / nbVivants!) * 100;
  }
}
