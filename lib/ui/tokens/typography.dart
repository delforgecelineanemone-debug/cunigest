import 'package:flutter/material.dart';

/// Typographie CuniUI — police Inter bundlée dans l'app.
///
/// Inter est embarquée comme police variable (`assets/fonts/Inter-Variable.ttf`,
/// déclarée dans pubspec.yaml). Aucun téléchargement réseau : le rendu est
/// identique hors-ligne et le premier lancement n'attend pas le réseau.
abstract final class CuTypography {
  static const String _family = 'Inter';

  /// TextTheme complet Inter — à passer dans ThemeData.textTheme.
  static const TextTheme textTheme = TextTheme(
    displayLarge:
        TextStyle(fontFamily: _family, fontSize: 32, fontWeight: FontWeight.w700),
    displayMedium:
        TextStyle(fontFamily: _family, fontSize: 28, fontWeight: FontWeight.w700),
    displaySmall:
        TextStyle(fontFamily: _family, fontSize: 24, fontWeight: FontWeight.w700),
    headlineLarge:
        TextStyle(fontFamily: _family, fontSize: 22, fontWeight: FontWeight.w600),
    headlineMedium:
        TextStyle(fontFamily: _family, fontSize: 20, fontWeight: FontWeight.w600),
    headlineSmall:
        TextStyle(fontFamily: _family, fontSize: 18, fontWeight: FontWeight.w600),
    titleLarge:
        TextStyle(fontFamily: _family, fontSize: 17, fontWeight: FontWeight.w600),
    titleMedium:
        TextStyle(fontFamily: _family, fontSize: 15, fontWeight: FontWeight.w600),
    titleSmall:
        TextStyle(fontFamily: _family, fontSize: 13, fontWeight: FontWeight.w600),
    bodyLarge:
        TextStyle(fontFamily: _family, fontSize: 15, fontWeight: FontWeight.w400),
    bodyMedium:
        TextStyle(fontFamily: _family, fontSize: 14, fontWeight: FontWeight.w400),
    bodySmall:
        TextStyle(fontFamily: _family, fontSize: 13, fontWeight: FontWeight.w400),
    labelLarge:
        TextStyle(fontFamily: _family, fontSize: 14, fontWeight: FontWeight.w600),
    labelMedium:
        TextStyle(fontFamily: _family, fontSize: 13, fontWeight: FontWeight.w500),
    labelSmall:
        TextStyle(fontFamily: _family, fontSize: 11, fontWeight: FontWeight.w500),
  );

  /// Style Inter ponctuel — équivalent de l'ancien `GoogleFonts.inter(...)`.
  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      TextStyle(
        fontFamily: _family,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
}
