// ──────────────────────────────────────────────────────────────
// UndoHelper — Pattern "delete + undo SnackBar" standardisé
// ──────────────────────────────────────────────────────────────
// Toute suppression critique passe par ce helper pour :
//   • feedback tactile fort (HapticFeedback.heavyImpact) signal danger
//   • SnackBar "Annuler" pendant 5 secondes
//   • restauration via callback `restore` (réinsertion repo)
//
// ⚠ Limite connue : la restauration ne ressuscite PAS les lignes
// supprimées en cascade (ex: soins liés à un lapin avec ON DELETE
// CASCADE). C'est acceptable pour un undo immédiat (5s) :
// l'utilisateur a juste perdu l'objet principal qu'il voulait garder.
//
// Pour un vrai soft delete avec récupération après restart, voir
// la roadmap "Sprint 3+" (migration v17 deleted_at).
//
// Usage type dans un écran de liste :
//
//   await UndoHelper.deleteWithUndo(
//     context: context,
//     label: 'Lapin "Pépite"',
//     delete: () async => await repo.delete(lapin.id!),
//     restore: () async => await repo.insert(lapin),
//   );
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/theme.dart';

class UndoHelper {
  UndoHelper._();

  /// Supprime puis affiche une SnackBar "Annuler" pendant 5 secondes.
  /// Si l'utilisateur clique ANNULER → appelle `restore`.
  ///
  /// `label` : texte affiché dans la SnackBar (ex: 'Lapin "Pépite"').
  /// `delete` / `restore` : callbacks async.
  /// `undoDuration` : durée de la fenêtre d'annulation (défaut 5s).
  static Future<void> deleteWithUndo({
    required BuildContext context,
    required String label,
    required Future<void> Function() delete,
    required Future<void> Function() restore,
    Duration undoDuration = const Duration(seconds: 5),
    VoidCallback? onUndone,
  }) async {
    // Vibration tactile forte = signal "action destructive validée".
    HapticFeedback.heavyImpact();
    try {
      await delete();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur suppression : $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;

    bool undone = false;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text('$label supprimé'),
        duration: undoDuration,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'ANNULER',
          textColor: Colors.white,
          onPressed: () async {
            undone = true;
            try {
              await restore();
              if (context.mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('$label restauré'),
                    backgroundColor: AppTheme.primary,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
              onUndone?.call();
            } catch (e) {
              if (context.mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Restauration impossible : $e'),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
            }
          },
        ),
      ),
    );
    await controller.closed;
    // Si la snackbar a été fermée sans undo, la suppression est définitive.
    // (le `undone` n'est utilisé que pour les hooks éventuels en aval).
    if (!undone) {/* suppression confirmée */}
  }
}
