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
/// ou autoriser le pop. Expose aussi `isSaving` pour afficher un
/// overlay bloquant pendant les sauvegardes (anti double-tap).
class CuFormController extends ChangeNotifier {
  bool _isDirty = false;
  bool _isSaving = false;
  String? _savingMessage;

  bool get isDirty => _isDirty;
  bool get isSaving => _isSaving;
  String? get savingMessage => _savingMessage;

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

  /// Active l'overlay "Enregistrement…" (barrier modal + spinner).
  /// L'utilisateur ne peut plus toucher le formulaire ni double-tapper
  /// "Enregistrer" tant que [markSaved] n'est pas appelé.
  void markSaving([String? message]) {
    if (_isSaving && _savingMessage == message) return;
    _isSaving = true;
    _savingMessage = message;
    notifyListeners();
  }

  /// Désactive l'overlay (à appeler en fin de save, success ou échec).
  void markSaved() {
    if (!_isSaving) return;
    _isSaving = false;
    _savingMessage = null;
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
            body: Stack(
              children: [
                child,
                if (controller.isSaving)
                  _SavingOverlay(message: controller.savingMessage),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Overlay modal affiché pendant `controller.isSaving = true`.
/// Bloque le double-tap "Enregistrer" et donne un feedback visuel clair.
class _SavingOverlay extends StatelessWidget {
  const _SavingOverlay({this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: true,
        child: Container(
          color: Colors.black.withValues(alpha: 0.35),
          alignment: Alignment.center,
          child: Card(
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    message ?? 'Enregistrement…',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
