// ──────────────────────────────────────────────────────────────
// Widgets réutilisables — CuniGest
// ──────────────────────────────────────────────────────────────
// Ce fichier contient les composants visuels utilisés dans
// plusieurs écrans de l'application :
// - StatCard : carte de statistique (tableau de bord)
// - SectionHeader : titre de section
// - AlertBanner : bandeau d'alerte
// - EmptyState : écran vide avec message
// - ConfirmDialog : dialogue de confirmation de suppression
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// Carte de statistique utilisée dans le tableau de bord
/// Affiche un chiffre avec un label, une icône et une couleur
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey.shade400),
                ],
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Titre de section avec un éventuel widget à droite (bouton, lien, etc.)
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Flexible(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Bandeau d'alerte coloré avec une icône et un message
/// Utilisé pour les rappels sanitaires et les stocks critiques
class AlertBanner extends StatelessWidget {
  final String message;
  final Color color;
  final IconData icon;

  const AlertBanner({
    super.key,
    required this.message,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Flexible(child: Text(message, style: TextStyle(color: color, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

/// Écran vide affiché quand une liste n'a pas de données
/// Avec un bouton d'action optionnel pour ajouter le premier élément
class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;
  final String? hint;
  final Color? color;

  const EmptyState({
    super.key,
    required this.message,
    required this.icon,
    this.onAction,
    this.actionLabel,
    this.hint,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ?? AppTheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: c.withValues(alpha: isDark ? 0.18 : 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: c),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
            if (onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel ?? 'Ajouter'),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

/// Dialogue de confirmation réutilisable pour les suppressions
/// Retourne true si l'utilisateur confirme, false sinon
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String cancelLabel = 'Annuler',
  String confirmLabel = 'Supprimer',
  Color? confirmColor,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: confirmColor != null
              ? ElevatedButton.styleFrom(backgroundColor: confirmColor)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Affiche un message de succès en bas de l'écran
void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: AppTheme.primary,
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 2),
  ));
}

/// Affiche un message d'erreur en bas de l'écran
void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: Colors.red,
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 3),
  ));
}

// ──────────────────────────────────────────────────────────────
// Widgets de formulaire réutilisables
// ──────────────────────────────────────────────────────────────

/// Titre de section dans les formulaires (ex: "📅 Dates", "💉 Type de soin")
/// Utilisé dans tous les écrans de formulaire pour regrouper les champs
class FormSection extends StatelessWidget {
  final String title;
  const FormSection(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}

/// Sélecteur de date réutilisable avec affichage formaté
/// Utilisé dans tous les formulaires nécessitant une date
class FormDatePicker extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String> onPicked;
  final VoidCallback? onClear;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const FormDatePicker({
    super.key,
    required this.label,
    required this.value,
    required this.onPicked,
    this.onClear,
    this.firstDate,
    this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final init = value != null ? DateTime.tryParse(value!) ?? DateTime.now() : DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: init,
          firstDate: firstDate ?? DateTime(2020),
          lastDate: lastDate ?? DateTime(2035),
        );
        if (picked != null) {
          onPicked(picked.toIso8601String().substring(0, 10));
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today),
          suffixIcon: value != null && onClear != null
              ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: onClear)
              : null,
        ),
        child: Text(
          value != null ? _formatDate(value!) : 'Non définie',
          style: TextStyle(
            color: value != null
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).hintColor,
          ),
        ),
      ),
    );
  }

  /// Format interne de date ISO → JJ/MM/AAAA
  String _formatDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }
}

/// Badge de statistique miniature (utilisé dans les en-têtes d'écrans)
/// Affiche un chiffre avec un label et une couleur
class MiniStatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const MiniStatBadge({
    super.key,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}
