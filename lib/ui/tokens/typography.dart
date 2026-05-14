import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class CuTypography {
  /// TextTheme complet Inter — à passer dans ThemeData.textTheme
  static TextTheme get textTheme => GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
            fontSize: 32, fontWeight: FontWeight.w700),
        displayMedium: GoogleFonts.inter(
            fontSize: 28, fontWeight: FontWeight.w700),
        displaySmall: GoogleFonts.inter(
            fontSize: 24, fontWeight: FontWeight.w700),
        headlineLarge: GoogleFonts.inter(
            fontSize: 22, fontWeight: FontWeight.w600),
        headlineMedium: GoogleFonts.inter(
            fontSize: 20, fontWeight: FontWeight.w600),
        headlineSmall: GoogleFonts.inter(
            fontSize: 18, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.inter(
            fontSize: 17, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w600),
        titleSmall: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w400),
        bodyMedium: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w400),
        bodySmall: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w400),
        labelLarge: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600),
        labelMedium: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w500),
        labelSmall: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w500),
      );
}
