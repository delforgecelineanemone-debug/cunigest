import 'package:flutter/material.dart';
import '../ui/tokens/colors.dart';
import '../ui/tokens/radius.dart';
import '../ui/tokens/typography.dart';

/// Thème visuel CuniGest — V3 « Field-Premium »
/// API rétrocompatible : tous les écrans existants continuent de fonctionner.
class AppTheme {
  // ── Palette principale (alias vers CuColors) ──
  static const Color primary = CuColors.primary;
  static const Color secondary = CuColors.primarySoft;
  static const Color accent = CuColors.accentFeed;
  static const Color background = CuColors.bgLight;
  static const Color surface = CuColors.cardLight;
  static const Color error = CuColors.danger;
  static const Color warning = CuColors.warning;
  static const Color border = CuColors.borderLight;
  static const Color textSecondary = CuColors.textSecondaryLight;

  // ── Modules sémantiques ──
  static const Color moduleElevage = CuColors.primary;
  static const Color moduleRepro = CuColors.accentRepro;
  static const Color moduleStock = CuColors.accentFeed;
  static const Color moduleFinance = CuColors.accentFinance;
  static const Color moduleOutils = CuColors.accentTools;
  static const Color moduleAdmin = CuColors.accentAdmin;

  static String devise = '€';

  static ThemeData get theme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isDark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: b);

    final cardColor = isDark ? CuColors.cardDark : CuColors.cardLight;
    final scaffoldBg = isDark ? CuColors.bgDark : CuColors.bgLight;
    final navBg = isDark ? CuColors.navBgDark : CuColors.navBgLight;
    final inputFill = isDark ? CuColors.raisedDark : CuColors.raisedLight;
    final borderColor = isDark ? CuColors.borderDark : CuColors.borderLight;
    final unselectedLabel = isDark
        ? CuColors.textSecondaryDark
        : CuColors.textSecondaryLight;

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      textTheme: CuTypography.textTheme,
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? CuColors.cardDark : primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: CuTypography.textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 2,
        shape: CuRadius.mdShape,
        color: cardColor,
        shadowColor: const Color(0x14000000),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: CuRadius.mdAll,
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: CuRadius.mdAll,
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: CuRadius.mdAll,
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: CuRadius.mdShape,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(0, 48),
          textStyle: CuTypography.textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: borderColor),
          shape: CuRadius.mdShape,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(0, 48),
          textStyle: CuTypography.textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(0, 44),
          textStyle: CuTypography.textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? CuColors.raisedDark : CuColors.raisedLight,
        shape: RoundedRectangleBorder(
          borderRadius: CuRadius.fullAll,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelStyle: CuTypography.textTheme.labelMedium?.copyWith(
          color: isDark ? CuColors.textPrimaryDark : CuColors.textPrimaryLight,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: navBg,
        indicatorColor: primary.withValues(alpha: 0.18),
        selectedIconTheme: const IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(color: unselectedLabel),
        selectedLabelTextStyle:
            CuTypography.textTheme.labelSmall?.copyWith(color: primary),
        unselectedLabelTextStyle:
            CuTypography.textTheme.labelSmall?.copyWith(color: unselectedLabel),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBg,
        indicatorColor: primary.withValues(alpha: 0.18),
        height: 76,
        elevation: 4,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = CuTypography.textTheme.labelSmall!;
          if (states.contains(WidgetState.selected)) {
            return base.copyWith(
                fontWeight: FontWeight.w600, color: primary);
          }
          return base.copyWith(color: unselectedLabel);
        }),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? CuColors.borderDark : CuColors.borderLight,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: CuRadius.mdShape,
        backgroundColor: isDark ? CuColors.raisedDark : CuColors.cardDark,
        contentTextStyle:
            CuTypography.textTheme.bodyMedium?.copyWith(color: Colors.white),
      ),
      dialogTheme: DialogThemeData(
        shape: CuRadius.lgShape,
        backgroundColor: cardColor,
        titleTextStyle: CuTypography.textTheme.titleLarge?.copyWith(
          color: isDark ? CuColors.textPrimaryDark : CuColors.textPrimaryLight,
        ),
        contentTextStyle: CuTypography.textTheme.bodyMedium?.copyWith(
          color: isDark ? CuColors.textSecondaryDark : CuColors.textSecondaryLight,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Fonctions utilitaires — inchangées pour rétrocompatibilité
// ──────────────────────────────────────────────────────────────

String formatDate(String? dateStr) {
  if (dateStr == null) return '-';
  try {
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  } catch (_) {
    return dateStr;
  }
}

String today() => DateTime.now().toIso8601String().substring(0, 10);

Color statutColor(String statut) {
  switch (statut) {
    case 'actif':
      return CuColors.statutActif;
    case 'vendu':
      return CuColors.statutVendu;
    case 'mort':
      return CuColors.statutMort;
    case 'sevrage':
      return CuColors.statutSevrage;
    case 'quarantaine':
      return CuColors.statutQuarantaine;
    default:
      return Colors.grey;
  }
}

String formatMontant(double? montant) {
  if (montant == null) return '-';
  return '${montant.toStringAsFixed(2)} ${AppTheme.devise}';
}

Color cageStatutColor(String statut) {
  switch (statut) {
    case 'vide':
      return CuColors.cageVide;
    case 'occupee':
      return CuColors.cageOccupee;
    case 'pleine':
      return CuColors.cageAllaitement; // rose foncé : saturée
    case 'gestante':
      return CuColors.cageGestante;
    case 'allaitement':
      return CuColors.cageAllaitement;
    case 'sevrage':
      return CuColors.cageSevrage;
    case 'quarantaine':
      return CuColors.cageQuarantaine;
    case 'desinfection':
      return CuColors.cageDesinfection;
    case 'maintenance':
      return CuColors.cageMaintenance;
    default:
      return Colors.grey;
  }
}

IconData cageStatutIcon(String statut) {
  switch (statut) {
    case 'vide':
      return Icons.crop_square;
    case 'occupee':
      return Icons.pets;
    case 'pleine':
      return Icons.groups;
    case 'gestante':
      return Icons.pregnant_woman;
    case 'allaitement':
      return Icons.child_care;
    case 'sevrage':
      return Icons.escalator_warning;
    case 'quarantaine':
      return Icons.medical_services;
    case 'desinfection':
      return Icons.cleaning_services;
    case 'maintenance':
      return Icons.handyman;
    default:
      return Icons.crop_square;
  }
}
