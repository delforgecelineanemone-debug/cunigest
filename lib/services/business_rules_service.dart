// ──────────────────────────────────────────────────────────────
// BusinessRulesService — Vérifications métier centralisées
// ──────────────────────────────────────────────────────────────
// Règles invariantes vérifiées AVANT submit pour empêcher la
// corruption silencieuse des données :
//
//   • saillie : femelle déjà gestante ?
//   • saillie : mise bas réelle >= date saillie ?
//   • soin    : lapin actif (pas mort/vendu) ?
//   • soin    : filtrer la liste "tout l'élevage" (exclut morts/vendus)
//   • lapin   : doublon de bague avant submit (UX rapide)
//
// Tous les helpers renvoient `null` si tout va bien, ou une `String`
// contenant le message d'erreur à afficher à l'utilisateur. Cela
// permet de les composer librement dans un _save() :
//
//   final err = await BusinessRules.peutCreerSaillie(...);
//   if (err != null) { showErrorSnackBar(context, err); return; }
//
// Ces vérifications complètent — sans remplacer — les validators
// de formulaires (cf. lib/utils/validators.dart) qui sont synchrones.
// ──────────────────────────────────────────────────────────────

import '../database/db_helper.dart';
import '../models/lapin.dart';
import '../models/saillie.dart';

class BusinessRules {
  BusinessRules._();

  /// Statuts de saillie qui indiquent une gestation EN COURS
  /// (femelle pas re-saillible tant qu'on n'a pas atteint termine/echec).
  static const Set<String> _statutsEnCours = {
    'en_attente',
    'mise_bas',
    'sevrage',
  };

  // ────────────────────────────────────────────────────────────
  // Saillies
  // ────────────────────────────────────────────────────────────

  /// Renvoie un message d'erreur si la femelle a déjà une saillie en cours,
  /// `null` sinon. Permet d'éviter 2 mise-bas prévues qui se chevauchent.
  ///
  /// `saillieIdEnEdition` : si renseigné, on ignore cette saillie dans la
  /// recherche (cas d'édition).
  static Future<String?> femelleDejaGestante({
    required int mereId,
    int? saillieIdEnEdition,
  }) async {
    final repo = await DBHelper.instance.saillies;
    final saillies = await repo.getSailliesByMere(mereId);
    final enCours = saillies.firstWhere(
      (s) =>
          s.id != saillieIdEnEdition &&
          _statutsEnCours.contains(s.statut),
      orElse: () => _saillieVide(),
    );
    if (enCours.id == null) return null;

    final mb = enCours.dateMiseBasPrevue ?? enCours.dateSaillie;
    return 'Cette femelle a déjà une saillie en cours (mise bas prévue le $mb). '
        'Terminez-la ou marquez-la "échec" avant d\'en créer une nouvelle.';
  }

  /// Vérifie que la mise-bas réelle n'est pas antérieure à la date de saillie.
  static String? miseBasCoherente({
    required String dateSaillieIso,
    String? dateMiseBasReelleIso,
  }) {
    if (dateMiseBasReelleIso == null) return null;
    final ds = DateTime.tryParse(dateSaillieIso);
    final dm = DateTime.tryParse(dateMiseBasReelleIso);
    if (ds == null || dm == null) return null;
    if (dm.isBefore(ds)) {
      return 'La mise bas (${_fmt(dm)}) ne peut pas être avant la saillie (${_fmt(ds)}).';
    }
    // Sanity check : gestation lapine ~28-33 jours. Au-delà de 50 j on
    // signale (le lapereau ne survivrait pas + erreur de saisie probable).
    final ecart = dm.difference(ds).inDays;
    if (ecart > 50) {
      return 'Écart anormal entre saillie et mise bas ($ecart jours). Vérifiez les dates.';
    }
    return null;
  }

  // ────────────────────────────────────────────────────────────
  // Soins
  // ────────────────────────────────────────────────────────────

  /// Filtre la liste de lapins pour ne garder que ceux éligibles à un soin
  /// (statut = 'actif'). Empêche d'appliquer un traitement à un lapin
  /// mort/vendu (coûts faussés, délais d'attente inutiles).
  static List<Lapin> lapinsEligiblesSoin(Iterable<Lapin> lapins) {
    return lapins.where((l) => l.statut == 'actif').toList();
  }

  /// Renvoie un message si le lapin ciblé ne peut pas recevoir un soin.
  static String? peutRecevoirSoin(Lapin? lapin) {
    if (lapin == null) return 'Lapin introuvable.';
    if (lapin.statut == 'mort') {
      return 'Ce lapin est mort — aucun soin ne peut être enregistré.';
    }
    if (lapin.statut == 'vendu') {
      return 'Ce lapin est vendu — aucun soin ne peut être enregistré.';
    }
    return null;
  }

  // ────────────────────────────────────────────────────────────
  // Lapins — doublons bague
  // ────────────────────────────────────────────────────────────

  /// Renvoie un message si la bague est déjà utilisée par un autre lapin.
  /// `lapinIdEnEdition` : si renseigné, on ignore ce lapin (cas d'édition).
  ///
  /// Côté DB il y a déjà une contrainte UNIQUE — mais cette vérification
  /// côté client permet d'afficher l'erreur AVANT submit, sans devoir
  /// recharger toute la requête.
  static Future<String?> bagueDejaUtilisee({
    required String bague,
    int? lapinIdEnEdition,
  }) async {
    final tag = bague.trim();
    if (tag.isEmpty) return null;
    final lapins = await (await DBHelper.instance.lapins).getAllLapins();
    final doublon = lapins.firstWhere(
      (l) =>
          l.numeroBague.toLowerCase() == tag.toLowerCase() &&
          l.id != lapinIdEnEdition,
      orElse: () => Lapin(numeroBague: '__none__', sexe: 'femelle'),
    );
    if (doublon.numeroBague == '__none__') return null;
    final nom = doublon.nom?.isNotEmpty == true
        ? doublon.nom
        : 'lapin #${doublon.id}';
    return 'La bague "$tag" est déjà utilisée par $nom.';
  }

  // ────────────────────────────────────────────────────────────
  // Helpers privés
  // ────────────────────────────────────────────────────────────

  static Saillie _saillieVide() =>
      Saillie(mereId: 0, pereId: 0, dateSaillie: '');

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
