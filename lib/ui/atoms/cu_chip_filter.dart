import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Chip de filtre animé — sélection dans les listes (Tous / ♂ / ♀ / etc.)
class CuChipFilter extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final IconData? icon;
  final int? count;

  const CuChipFilter({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.icon,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = color ?? CuColors.primary;

    final bg = selected
        ? accent
        : (isDark ? CuColors.raisedDark : CuColors.raisedLight);
    final fg = selected
        ? Colors.white
        : (isDark ? CuColors.textSecondaryDark : CuColors.textSecondaryLight);
    final border = selected
        ? null
        : Border.all(
            color: isDark ? CuColors.borderDark : CuColors.borderLight,
          );

    return Semantics(
      label: count != null ? '$label, $count' : label,
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: CuSpacing.md,
          vertical: CuSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: CuRadius.fullAll,
          border: border,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: CuSpacing.xs),
            ],
            Text(
              label,
              style: CuTypography.textTheme.labelMedium?.copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: fg,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: CuSpacing.xs),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.2),
                  borderRadius: CuRadius.fullAll,
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
