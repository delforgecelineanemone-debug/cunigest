// ──────────────────────────────────────────────────────────────
// RepositoryValidators — gardes synchrones appelées par les repos
// ──────────────────────────────────────────────────────────────
// Ces assertions sont la dernière barrière entre l'application et
// la base SQLite. Elles bloquent les insertions / updates qui
// violeraient les invariants métier — peu importe la source
// (formulaire UI, import CSV, restauration backup, pull cloud
// corrompu, script de seed).
//
// Toute violation lance une `ArgumentError`. L'UI doit attraper
// et afficher un SnackBar — mais une exception ici signale en
// général un bug en amont (validator UI manquant, donnée importée
// invalide). À voir dans les logs Sentry.
//
// Note : les vérifications NÉCESSITANT un accès DB (femelle déjà
// gestante, doublon de bague, etc.) restent dans `BusinessRules`
// (services/business_rules_service.dart) — appelées en amont par
// les formulaires.
// ──────────────────────────────────────────────────────────────

import '../models/lapin.dart';
import '../models/saillie.dart';
import '../models/soin.dart';
import '../models/vente.dart';
import '../models/depense.dart';

class RepositoryValidators {
  RepositoryValidators._();

  // ── Lapin ─────────────────────────────────────────────────

  static const Set<String> kSexesValides = {'male', 'femelle'};

  /// Statuts acceptés en base. Volontairement large : on bloque les
  /// valeurs aberrantes (faute de frappe, données corrompues) mais on
  /// accepte tous les statuts métier connus + historiques.
  static const Set<String> kStatutsLapinValides = {
    'actif', 'reproducteur', 'sevrage', 'engraissement',
    'quarantaine', 'vendu', 'mort',
  };

  /// Garde-fou d'intégrité — bloque uniquement les incohérences DURES
  /// (données qui corrompraient les requêtes / stats). Les exigences de
  /// COMPLÉTUDE de saisie (ex. cause de mortalité obligatoire) restent
  /// du ressort des validators de formulaire — les imposer ici casserait
  /// les imports CSV, le seed de test et le pull cloud de données legacy.
  static void assertValidLapin(Lapin l) {
    final bague = l.numeroBague.trim();
    if (bague.isEmpty) {
      throw ArgumentError('Le numéro de bague est obligatoire.');
    }
    if (!kSexesValides.contains(l.sexe)) {
      throw ArgumentError('Sexe invalide : "${l.sexe}". Attendu : male ou femelle.');
    }
    if (!kStatutsLapinValides.contains(l.statut)) {
      throw ArgumentError('Statut lapin invalide : "${l.statut}".');
    }
    if (l.poids != null && l.poids! < 0) {
      throw ArgumentError('Le poids ne peut pas être négatif (${l.poids} kg).');
    }
    if (l.prixAchat != null && l.prixAchat! < 0) {
      throw ArgumentError('Le prix d\'achat ne peut pas être négatif.');
    }
    if (l.id != null && (l.pereId == l.id || l.mereId == l.id)) {
      throw ArgumentError('Un lapin ne peut pas être son propre parent.');
    }
    if (l.pereId != null && l.mereId != null && l.pereId == l.mereId) {
      throw ArgumentError('Père et mère ne peuvent pas être le même animal.');
    }
  }

  // ── Saillie ───────────────────────────────────────────────

  static const Set<String> kStatutsSaillieValides = {
    'en_attente', 'mise_bas', 'sevrage', 'termine', 'echec',
  };

  static void assertValidSaillie(Saillie s) {
    if (s.mereId == s.pereId) {
      throw ArgumentError('La mère et le père ne peuvent pas être le même animal.');
    }
    if (s.mereId <= 0 || s.pereId <= 0) {
      throw ArgumentError('IDs de mère et père requis.');
    }
    if (s.dateSaillie.isEmpty) {
      throw ArgumentError('La date de saillie est obligatoire.');
    }
    if (!kStatutsSaillieValides.contains(s.statut)) {
      throw ArgumentError('Statut saillie invalide : "${s.statut}".');
    }
    final ds = DateTime.tryParse(s.dateSaillie);
    if (ds == null) {
      throw ArgumentError('Date de saillie illisible : "${s.dateSaillie}".');
    }
    if (s.dateMiseBasReelle != null) {
      final dm = DateTime.tryParse(s.dateMiseBasReelle!);
      if (dm != null && dm.isBefore(ds)) {
        throw ArgumentError('La mise bas ne peut pas être avant la saillie.');
      }
    }
    if (s.nbVivants != null && s.nbVivants! < 0) {
      throw ArgumentError('Nombre de vivants négatif interdit.');
    }
    if (s.nbMorts != null && s.nbMorts! < 0) {
      throw ArgumentError('Nombre de morts négatif interdit.');
    }
    if (s.nbSevres != null && s.nbVivants != null && s.nbSevres! > s.nbVivants!) {
      throw ArgumentError('Sevrés (${s.nbSevres}) ne peut pas dépasser vivants (${s.nbVivants}).');
    }
  }

  // ── Soin ──────────────────────────────────────────────────

  static void assertValidSoin(Soin s) {
    if (s.typeSoin.trim().isEmpty) {
      throw ArgumentError('Le type de soin est obligatoire.');
    }
    if (s.dateSoin.isEmpty) {
      throw ArgumentError('La date du soin est obligatoire.');
    }
    if (s.cout != null && s.cout! < 0) {
      throw ArgumentError('Le coût ne peut pas être négatif.');
    }
    if (s.delaiAttenteJours != null && s.delaiAttenteJours! < 0) {
      throw ArgumentError('Délai d\'attente négatif interdit.');
    }
  }

  // ── Vente ─────────────────────────────────────────────────

  static void assertValidVente(Vente v) {
    if (v.prixVente < 0) {
      throw ArgumentError('Le prix de vente ne peut pas être négatif.');
    }
    if (v.dateVente.isEmpty) {
      throw ArgumentError('La date de vente est obligatoire.');
    }
    if (v.typeVente.trim().isEmpty) {
      throw ArgumentError('Le type de vente est obligatoire.');
    }
    if (v.quantite <= 0) {
      throw ArgumentError('La quantité vendue doit être > 0.');
    }
    if (v.poids != null && v.poids! < 0) {
      throw ArgumentError('Le poids ne peut pas être négatif.');
    }
  }

  // ── Dépense ───────────────────────────────────────────────

  static void assertValidDepense(Depense d) {
    if (d.montant < 0) {
      throw ArgumentError('Le montant d\'une dépense ne peut pas être négatif.');
    }
    if (d.categorie.trim().isEmpty) {
      throw ArgumentError('La catégorie de dépense est obligatoire.');
    }
    if (d.dateDepense.isEmpty) {
      throw ArgumentError('La date de la dépense est obligatoire.');
    }
  }
}
