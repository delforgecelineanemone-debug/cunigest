import 'package:flutter/material.dart';

abstract final class AppBreakpoints {
  static const double tablet = 600;
  static const double desktop = 1200;
}

extension ContextBreakpoints on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isMobile => screenWidth < AppBreakpoints.tablet;
  bool get isTablet =>
      screenWidth >= AppBreakpoints.tablet &&
      screenWidth < AppBreakpoints.desktop;
  bool get isDesktop => screenWidth >= AppBreakpoints.desktop;

  /// true pour tablette et desktop (layout large)
  bool get isWide => screenWidth >= AppBreakpoints.tablet;

  /// Colonnes de la grille KPI : 2 sur téléphone, 4 sur tablette/desktop
  int get kpiColumns => isWide ? 4 : 2;

  /// Colonnes de la grille modules (écran Plus) : 2 → 3 → 4
  int get moduleColumns => isDesktop ? 4 : isTablet ? 3 : 2;

  /// Padding horizontal adaptatif
  double get hPad => isDesktop ? 48.0 : isTablet ? 24.0 : 16.0;

  /// Largeur max du contenu (pour centrer sur desktop)
  double get contentMaxWidth => isDesktop ? 1200.0 : double.infinity;
}
