import 'package:flutter/material.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Badge pill coloré — statuts, labels, compteurs.
/// [filled] = fond plein (blanc sur couleur) vs fond doux (couleur @12%).
class CuBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final double? fontSize;
  final IconData? icon;

  const CuBadge({
    super.key,
    required this.label,
    required this.color,
    this.filled = false,
    this.fontSize,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled ? color : color.withValues(alpha: 0.12);
    final fg = filled ? Colors.white : color;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CuSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: CuRadius.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: (fontSize ?? 12) + 1, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: CuTypography.textTheme.labelSmall?.copyWith(
              fontSize: fontSize ?? 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
