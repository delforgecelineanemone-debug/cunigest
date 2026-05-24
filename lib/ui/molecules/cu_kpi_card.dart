import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/shadows.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Carte KPI dashboard — valeur + label + delta optionnel + tap.
/// Affiche un skeleton si [loading] est true.
class CuKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? delta;       // ex: "+5" ou "-2%" (vert si positif, rouge si négatif)
  final bool deltaPositiveIsGood; // false pour mortalité (hausse = mauvais)
  final bool loading;
  final VoidCallback? onTap;

  const CuKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.delta,
    this.deltaPositiveIsGood = true,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? CuColors.cardDark : CuColors.cardLight;

    // A11y : un lecteur d'écran annonce « <label> : <valeur> [delta] »
    // au lieu de lire séparément l'icône, le chiffre et le texte.
    final semanticLabel = loading
        ? '$label, chargement en cours'
        : '$label : $value${delta != null ? ', évolution $delta' : ''}';

    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: CuRadius.mdAll,
            boxShadow: isDark ? CuShadows.none : CuShadows.level1,
          ),
          padding: const EdgeInsets.all(CuSpacing.lg),
          child: loading ? _skeleton(isDark) : _content(isDark),
        ),
      ),
    );
  }

  Widget _content(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: CuRadius.smAll,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const Spacer(),
            if (delta != null) _deltaBadge(),
          ],
        ),
        const SizedBox(height: CuSpacing.sm),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: CuTypography.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: isDark ? CuColors.textPrimaryDark : CuColors.textPrimaryLight,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: CuTypography.textTheme.labelSmall?.copyWith(
            color: isDark ? CuColors.textSecondaryDark : CuColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _deltaBadge() {
    if (delta == null) return const SizedBox.shrink();
    final isPos = delta!.startsWith('+') || (!delta!.startsWith('-'));
    final good = deltaPositiveIsGood ? isPos : !isPos;
    final badgeColor = good ? CuColors.success : CuColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: CuRadius.fullAll,
      ),
      child: Text(
        delta!,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: badgeColor,
        ),
      ),
    );
  }

  Widget _skeleton(bool isDark) {
    final shimmer = isDark ? CuColors.raisedDark : CuColors.raisedLight;
    bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: shimmer,
            borderRadius: CuRadius.smAll,
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        bar(32, 32),
        const SizedBox(height: CuSpacing.sm),
        bar(64, 22),
        const SizedBox(height: 5),
        bar(80, 10),
      ],
    );
  }
}
