import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/typography.dart';

/// Sélecteur segmenté animé (style iOS) pour filtrage rapide.
/// Usage : sexe ♂/♀, statut actif/vendu/mort, vue semaine/mois…
class CuSegmented<T> extends StatelessWidget {
  final List<CuSegmentItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;
  final Color? color;

  const CuSegmented({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = color ?? CuColors.primary;
    final bg = isDark ? CuColors.raisedDark : CuColors.raisedLight;

    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: CuRadius.mdAll,
        border: Border.all(
          color: isDark ? CuColors.borderDark : CuColors.borderLight,
        ),
      ),
      child: Row(
        children: items.map((item) {
          final isSelected = item.value == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (!isSelected) {
                  HapticFeedback.selectionClick();
                  onChanged(item.value);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: isSelected ? accent : Colors.transparent,
                  borderRadius: CuRadius.smAll,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (item.icon != null) ...[
                      Icon(
                        item.icon,
                        size: 14,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? CuColors.textSecondaryDark
                                : CuColors.textSecondaryLight),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      item.label,
                      style: CuTypography.textTheme.labelMedium?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? CuColors.textSecondaryDark
                                : CuColors.textSecondaryLight),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class CuSegmentItem<T> {
  final T value;
  final String label;
  final IconData? icon;

  const CuSegmentItem({
    required this.value,
    required this.label,
    this.icon,
  });
}
