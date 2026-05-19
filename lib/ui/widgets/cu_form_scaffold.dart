// ──────────────────────────────────────────────────────────────
// CuFormScaffold — Scaffold standard pour TOUS les formulaires
// ──────────────────────────────────────────────────────────────
// Protège l'éleveur contre les pertes de saisie accidentelles :
// si le formulaire est "dirty" (modifié non sauvé), un dialog
// "Quitter sans enregistrer ?" intercepte le back.
//
// Usage type dans un _State<MyFormScreen> :
//
//   final _formCtrl = CuFormController();
//
//   @override
//   Widget build(BuildContext context) {
//     return CuFormScaffold(
//       controller: _formCtrl,
//       appBar: CuAppBar(title: 'Mon formulaire'),
//       child: Form(
//         onChanged: () => _formCtrl.markDirty(),
//         child: ...,
//       ),
//     );
//   }
//
//   // Après save réussi, marquer propre pour autoriser le pop :
//   _formCtrl.markClean();
//
// La détection "dirty" peut aussi être déclenchée manuellement
// sur tout changement d'état hors Form (Switch, DatePicker, etc.).
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/theme.dart';

/// Contrôleur du formulaire. Expose un flag `isDirty` modifiable
/// par le formulaire parent ; le scaffold l'écoute pour bloquer
/// ou autoriser le pop.
class CuFormController extends ChangeNotifier {
  bool _isDirty = false;

  bool get isDirty => _isDirty;

  /// Marque le formulaire comme modifié (à appeler dans onChanged).
  /// Idempotent : ne notifie que si l'état change réellement.
  void markDirty() {
    if (_isDirty) return;
    _isDirty = true;
    notifyListeners();
  }

  /// Marque le formulaire comme propre (après save réussi ou reset).
  void markClean() {
    if (!_isDirty) return;
    _isDirty = false;
    notifyListeners();
  }
}

class CuFormScaffold extends StatelessWidget {
  /// Contrôleur partagé avec le formulaire parent.
  final CuFormController controller;

  /// AppBar — typiquement CuAppBar.
  final PreferredSizeWidget? appBar;

  /// Contenu du formulaire.
  final Widget child;

  /// Bouton flottant éventuel (FAB).
  final Widget? floatingActionButton;

  /// Couleur de fond optionnelle.
  final Color? backgroundColor;

  /// Titre custom du dialog (défaut : "Quitter sans enregistrer ?").
  final String dialogTitle;

  /// Message custom (défaut explicite + action irréversible).
  final String dialogMessage;

  /// Texte du bouton confirmation (défaut : "Quitter").
  final String dialogConfirmLabel;

  /// Texte du bouton annulation (défaut : "Continuer la saisie").
  final String dialogCancelLabel;

  const CuFormScaffold({
    super.key,
    required this.controller,
    required this.child,
    this.appBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.dialogTitle = 'Quitter sans enregistrer ?',
    this.dialogMessage =
        'Les modifications saisies seront perdues. Cette action est définitive.',
    this.dialogConfirmLabel = 'Quitter',
    this.dialogCancelLabel = 'Continuer la saisie',
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return PopScope(
          canPop: !controller.isDirty,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final navigator = Navigator.of(context);
            // Vibration tactile = signal "attention, action à confirmer"
            HapticFeedback.mediumImpact();
            final quitter = await showConfirmDialog(
              context,
              title: dialogTitle,
              message: dialogMessage,
              cancelLabel: dialogCancelLabel,
              confirmLabel: dialogConfirmLabel,
              confirmColor: AppTheme.error,
            );
            if (quitter && navigator.canPop()) {
              navigator.pop();
            }
          },
          child: Scaffold(
            appBar: appBar,
            backgroundColor: backgroundColor,
            floatingActionButton: floatingActionButton,
            body: child,
          ),
        );
      },
    );
  }
}
