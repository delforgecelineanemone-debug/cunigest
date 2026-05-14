import 'package:flutter/material.dart';
import '../atoms/cu_button.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Écran vide premium — icône dans cercle + titre + hint + CTA.
/// Remplace l'ancien EmptyState de common_widgets.dart.
class CuEmptyState extends StatelessWidget {
  final String title;
  final String? hint;
  final IconData icon;
  final Color? color;
  final String? actionLabel;
  final VoidCallback? onAction;

  const CuEmptyState({
    super.key,
    required this.title,
    required this.icon,
    this.hint,
    this.color,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = color ?? CuColors.primary;
    final textPrimary =
        isDark ? CuColors.textPrimaryDark : CuColors.textPrimaryLight;
    final textSecondary =
        isDark ? CuColors.textSecondaryDark : CuColors.textSecondaryLight;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CuSpacing.x2l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.16 : 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 52, color: accent),
            ),
            const SizedBox(height: CuSpacing.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: CuTypography.textTheme.titleLarge
                  ?.copyWith(color: textPrimary),
            ),
            if (hint != null) ...[
              const SizedBox(height: CuSpacing.sm),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: CuTypography.textTheme.bodyMedium
                    ?.copyWith(color: textSecondary),
              ),
            ],
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: CuSpacing.xl),
              CuButton(
                label: actionLabel!,
                icon: Icons.add,
                onPressed: onAction,
                size: CuButtonSize.md,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
