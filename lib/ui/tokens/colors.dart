import 'package:flutter/material.dart';

/// Palette complète CuniUI V3 — « Field-Premium »
abstract final class CuColors {
  // ── Brand ──
  static const primary = Color(0xFF0F8C66);       // vert plus profond (AAA sur fond clair)
  static const primarySoft = Color(0xFFE6F4EE);   // fond doux primary
  static const primaryDarkVar = Color(0xFF3DBE93); // variant dark mode

  // ── Accents modules sémantiques ──
  static const accentRepro = Color(0xFF7C5CDB);    // reproduction (violet)
  static const accentReproDark = Color(0xFFA48FE8);
  static const accentHealth = Color(0xFFE24B4A);   // santé, alertes (rouge)
  static const accentHealthDark = Color(0xFFFF6B6A);
  static const accentFeed = Color(0xFFD85A30);     // stock alimentation (corail)
  static const accentFeedDark = Color(0xFFFF8A5C);
  static const accentFinance = Color(0xFFB47416);  // ventes, dépenses (ambre)
  static const accentFinanceDark = Color(0xFFE1A24E);
  static const accentTools = Color(0xFF1565C0);    // QR, calculatrices (bleu)
  static const accentToolsDark = Color(0xFF5B9BE8);
  static const accentAdmin = Color(0xFF546E7A);    // sync, réglages (gris bleuté)

  // ── Surfaces light ──
  static const bgLight = Color(0xFFFAF9F5);
  static const cardLight = Color(0xFFFFFFFF);
  static const raisedLight = Color(0xFFF2F0E9);
  static const navBgLight = Color(0xFFFFFFFF);

  // ── Surfaces dark ──
  static const bgDark = Color(0xFF0F1411);
  static const cardDark = Color(0xFF1A211D);
  static const raisedDark = Color(0xFF222B26);
  static const navBgDark = Color(0xFF1A211D);

  // ── Texte light ──
  static const textPrimaryLight = Color(0xFF1A1F1B);
  static const textSecondaryLight = Color(0xFF5C6660);
  static const textDisabledLight = Color(0xFF9AA29D);

  // ── Texte dark ──
  static const textPrimaryDark = Color(0xFFF1EFE8);
  static const textSecondaryDark = Color(0xFFA8B0AB);
  static const textDisabledDark = Color(0xFF5C6660);

  // ── Bordures ──
  static const borderLight = Color(0xFFE5E3DC);
  static const borderDark = Color(0xFF2A332E);

  // ── États sémantiques (light) ──
  static const success = Color(0xFF2D9B5A);
  static const warning = Color(0xFFE8A02C);
  static const danger = Color(0xFFD63B3A);
  static const info = Color(0xFF1565C0);

  // ── États sémantiques (dark) ──
  static const successDark = Color(0xFF52C77F);
  static const warningDark = Color(0xFFFFC265);
  static const dangerDark = Color(0xFFFF6B6A);
  static const infoDark = Color(0xFF5B9BE8);

  // ── Statuts lapin ──
  static const statutActif = primary;
  static const statutVendu = Color(0xFF1565C0);
  static const statutMort = Color(0xFF757575);
  static const statutSevrage = Color(0xFFEF6C00);
  static const statutQuarantaine = Color(0xFFB45309);

  // ── Statuts cage ──
  static const cageVide = Color(0xFF9E9E9E);
  static const cageOccupee = Color(0xFF1976D2);
  static const cageGestante = Color(0xFFEC407A);
  static const cageAllaitement = Color(0xFFAD1457);
  static const cageSevrage = Color(0xFFEF6C00);
  static const cageQuarantaine = Color(0xFFB45309);
  static const cageDesinfection = Color(0xFF7B1FA2);
  static const cageMaintenance = Color(0xFF424242);
}
