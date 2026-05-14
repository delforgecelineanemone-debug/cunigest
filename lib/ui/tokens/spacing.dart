/// Grille 8-pt — espacement cohérent dans toute l'app
abstract final class CuSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double x2l = 32;
  static const double x3l = 48;

  // Padding horizontal par breakpoint
  static const double pageMobile = 16;
  static const double pageTablet = 24;
  static const double pageDesktop = 48;

  // Hauteurs tactiles minimales (Material 3 + accessibilité terrain)
  static const double touchMin = 48;    // minimum absolu
  static const double touchTerrain = 56; // mode gants / usage terrain
}
