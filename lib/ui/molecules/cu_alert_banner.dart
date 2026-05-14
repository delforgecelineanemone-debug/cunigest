import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

enum CuAlertLevel { info, success, warning, danger }

/// Bandeau d'alerte contextuel — 4 niveaux visuels.
/// Dismissible optionnel + action CTA à droite.
class CuAlertBanner extends StatelessWidget {
  final String message;
  final CuAlertLevel level;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  final IconData? icon;

  const CuAlertBanner({
    super.key,
    required this.message,
    this.level = CuAlertLevel.warning,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (color, defaultIcon) = switch (level) {
      CuAlertLevel.info => (
          isDark ? CuColors.infoDark : CuColors.info,
          Icons.info_outline,
        ),
      CuAlertLevel.success => (
          isDark ? CuColors.successDark : CuColors.success,
          Icons.check_circle_outline,
        ),
      CuAlertLevel.warning => (
          isDark ? CuColors.warningDark : CuColors.warning,
          Icons.warning_amber_outlined,
        ),
      CuAlertLevel.danger => (
          isDark ? CuColors.dangerDark : CuColors.danger,
          Icons.error_outline,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CuSpacing.lg,
        vertical: CuSpacing.md,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: CuRadius.mdAll,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon ?? defaultIcon, color: color, size: 20),
          const SizedBox(width: CuSpacing.md),
          Expanded(
            child: Text(
              message,
              style: CuTypography.textTheme.bodySmall?.copyWith(color: color),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: CuSpacing.sm),
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: CuTypography.textTheme.labelMedium?.copyWith(
                  color: color,
                  decoration: TextDecoration.underline,
                  decorationColor: color,
                ),
              ),
            ),
          ],
          if (onDismiss != null) ...[
            const SizedBox(width: CuSpacing.sm),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close, color: color, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}
