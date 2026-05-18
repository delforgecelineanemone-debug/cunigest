import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/theme.dart';
import '../atoms/cu_avatar.dart';
import '../atoms/cu_badge.dart';
import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Tile lapin pour les listes — avatar + infos + badge statut + actions swipe.
/// [onTap] → ouvre la fiche détail
/// [onSoin] / [onVente] / [onDeplacer] → actions rapides swipe
class CuLapinTile extends StatelessWidget {
  final String bague;
  final String? race;
  final String sexe;       // 'M' ou 'F'
  final String statut;     // 'actif', 'vendu', 'mort', 'sevrage', 'quarantaine'
  final double? poids;     // kg
  final String? cage;      // ex: "B12"
  final String? photoPath;
  final String? note;      // info rapide (ex: "Gestante J18")
  final bool alerte;       // badge alerte orange
  final VoidCallback? onTap;
  final VoidCallback? onSoin;
  final VoidCallback? onVente;
  final VoidCallback? onDeplacer;
  final String? heroTag;

  const CuLapinTile({
    super.key,
    required this.bague,
    required this.sexe,
    required this.statut,
    this.race,
    this.poids,
    this.cage,
    this.photoPath,
    this.note,
    this.alerte = false,
    this.onTap,
    this.onSoin,
    this.onVente,
    this.onDeplacer,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sexeColor =
        sexe == 'femelle' ? const Color(0xFFEC407A) : CuColors.accentTools;
    final sexeIcon = sexe == 'femelle' ? Icons.female : Icons.male;

    return Dismissible(
      key: ValueKey('lapin_$bague'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (_) async => false, // swipe = actions, pas de suppression
      background: _swipeAction(
        context,
        align: Alignment.centerLeft,
        color: CuColors.accentHealth,
        icon: Icons.medical_services_outlined,
        label: 'Soin',
        onTap: onSoin,
      ),
      secondaryBackground: _swipeAction(
        context,
        align: Alignment.centerRight,
        color: CuColors.accentFinance,
        icon: Icons.point_of_sale_outlined,
        label: 'Vente',
        onTap: onVente,
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap?.call();
        },
        borderRadius: CuRadius.mdAll,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: CuSpacing.lg,
            vertical: CuSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isDark ? CuColors.cardDark : CuColors.cardLight,
            border: Border(
              bottom: BorderSide(
                color: isDark ? CuColors.borderDark : CuColors.borderLight,
              ),
            ),
          ),
          child: Row(
            children: [
              // Avatar (Hero si heroTag fourni)
              heroTag != null
                  ? Hero(
                      tag: heroTag!,
                      child: CuAvatar(
                        photoPath: photoPath,
                        label: bague,
                        color: statutColor(statut),
                        size: 48,
                      ),
                    )
                  : CuAvatar(
                      photoPath: photoPath,
                      label: bague,
                      color: statutColor(statut),
                      size: 48,
                    ),
              const SizedBox(width: CuSpacing.md),
              // Infos principales
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          bague,
                          style: CuTypography.textTheme.titleMedium?.copyWith(
                            color: isDark
                                ? CuColors.textPrimaryDark
                                : CuColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(width: CuSpacing.xs),
                        Icon(sexeIcon, size: 14, color: sexeColor),
                        const Spacer(),
                        if (alerte)
                          const Icon(Icons.warning_amber,
                              size: 16, color: CuColors.warning),
                        const SizedBox(width: CuSpacing.xs),
                        CuBadge(
                          label: _statutLabel(statut),
                          color: statutColor(statut),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (race != null)
                          Text(
                            race!,
                            style: CuTypography.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? CuColors.textSecondaryDark
                                  : CuColors.textSecondaryLight,
                            ),
                          ),
                        if (race != null && cage != null)
                          Text(
                            '  ·  ',
                            style: TextStyle(
                              color: isDark
                                  ? CuColors.textDisabledDark
                                  : CuColors.textDisabledLight,
                            ),
                          ),
                        if (cage != null)
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: isDark
                                    ? CuColors.textSecondaryDark
                                    : CuColors.textSecondaryLight,
                              ),
                              Text(
                                cage!,
                                style: CuTypography.textTheme.bodySmall
                                    ?.copyWith(
                                  color: isDark
                                      ? CuColors.textSecondaryDark
                                      : CuColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        const Spacer(),
                        if (poids != null)
                          Text(
                            '${poids!.toStringAsFixed(1)} kg',
                            style: CuTypography.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? CuColors.textPrimaryDark
                                  : CuColors.textPrimaryLight,
                            ),
                          ),
                      ],
                    ),
                    if (note != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        note!,
                        style: CuTypography.textTheme.labelSmall?.copyWith(
                          color: CuColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: CuSpacing.sm),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: isDark
                    ? CuColors.textDisabledDark
                    : CuColors.textDisabledLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _swipeAction(
    BuildContext context, {
    required Alignment align,
    required Color color,
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: color.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: CuSpacing.xl),
        alignment: align,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statutLabel(String s) => switch (s) {
        'actif' => 'Actif',
        'vendu' => 'Vendu',
        'mort' => 'Mort',
        'sevrage' => 'Sevrage',
        'quarantaine' => 'Quarantaine',
        _ => s,
      };
}
