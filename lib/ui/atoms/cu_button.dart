import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

enum CuButtonVariant { primary, secondary, ghost, danger }

enum CuButtonSize { sm, md, lg }

/// Bouton principal CuniUI.
/// Variants : primary | secondary | ghost | danger
/// Tailles : sm (48 — Material min) | md (52) | lg (56 — terrain/gants)
///
/// V2.5 — Sprint 3 : sm passé de 40dp → 48dp pour respecter la guideline
/// Material 3 (cible tactile min 48x48). Avant : risque de mis-tap en
/// usage terrain (fatigue, mains pleines).
class CuButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final CuButtonVariant variant;
  final CuButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;

  const CuButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = CuButtonVariant.primary,
    this.size = CuButtonSize.md,
    this.icon,
    this.loading = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // V2.5 — Sprint 3 : hauteurs ≥ 48dp (cible tactile Material min).
    final height = switch (size) {
      CuButtonSize.sm => 48.0,
      CuButtonSize.md => 52.0,
      CuButtonSize.lg => 56.0,
    };

    final fontSize = switch (size) {
      CuButtonSize.sm => 14.0,
      CuButtonSize.md => 15.0,
      CuButtonSize.lg => 16.0,
    };

    final hPad = switch (size) {
      CuButtonSize.sm => CuSpacing.md,
      CuButtonSize.md => CuSpacing.lg,
      CuButtonSize.lg => CuSpacing.xl,
    };

    final (bgColor, fgColor, borderColor) = switch (variant) {
      CuButtonVariant.primary => (
          CuColors.primary,
          Colors.white,
          null,
        ),
      CuButtonVariant.secondary => (
          isDark
              ? CuColors.primarySoft.withValues(alpha: 0.2)
              : CuColors.primarySoft,
          CuColors.primary,
          null,
        ),
      CuButtonVariant.ghost => (
          Colors.transparent,
          isDark ? CuColors.textSecondaryDark : CuColors.textSecondaryLight,
          isDark ? CuColors.borderDark : CuColors.borderLight,
        ),
      CuButtonVariant.danger => (
          CuColors.danger,
          Colors.white,
          null,
        ),
    };

    final disabled = onPressed == null || loading;

    Widget child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: fgColor),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: fontSize + 2, color: fgColor),
                const SizedBox(width: CuSpacing.sm),
              ],
              Text(
                label,
                style: CuTypography.textTheme.labelLarge?.copyWith(
                  fontSize: fontSize,
                  color: fgColor,
                ),
              ),
            ],
          );

    final inner = Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      hint: loading ? 'En cours de chargement' : null,
      child: GestureDetector(
        onTap: disabled
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed!();
              },
        child: AnimatedOpacity(
          opacity: disabled ? 0.48 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: hPad),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: CuRadius.mdAll,
              border:
                  borderColor != null ? Border.all(color: borderColor) : null,
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: inner) : inner;
  }
}
