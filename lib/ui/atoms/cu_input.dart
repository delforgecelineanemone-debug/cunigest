// ──────────────────────────────────────────────────────────────
// CuInput — TextField standardisé du design system
// ──────────────────────────────────────────────────────────────
// Wrappe `TextFormField` avec :
//   - icône préfixe optionnelle
//   - validators composables
//   - label + helper centralisés
//   - cibles tactiles cohérentes (48dp min sur mobile, 56dp en mode gants)
//   - feedback d'erreur en sémantique CuColors.danger
//   - Semantics() pour l'accessibilité (label lu par TalkBack/VoiceOver)
//
// Préfère utiliser CuInput aux TextFormField bruts dans les formulaires
// — un seul endroit pour évoluer le style et les validations communes.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';

enum CuInputType { text, email, number, decimal, password, multiline, phone }

class CuInput extends StatelessWidget {
  /// Label affiché au-dessus du champ.
  final String label;

  /// Helper text affiché sous le champ (instructions, format attendu).
  final String? helper;

  /// Texte d'erreur explicite (override le résultat du validator).
  final String? errorText;

  /// Placeholder à l'intérieur du champ quand il est vide.
  final String? hint;

  /// Icône préfixe (à gauche de la valeur).
  final IconData? prefixIcon;

  /// Widget suffixe (typiquement IconButton pour show/hide password).
  final Widget? suffix;

  /// Type de saisie — pilote keyboardType, autofillHints, inputFormatters.
  final CuInputType type;

  /// Contrôleur du champ.
  final TextEditingController? controller;

  /// Valeur initiale (si pas de controller).
  final String? initialValue;

  /// Validator synchrone. Retourner `null` = valide, sinon message d'erreur.
  final String? Function(String?)? validator;

  /// Callback sur changement.
  final ValueChanged<String>? onChanged;

  /// Action clavier (Done, Next, Search…).
  final TextInputAction? textInputAction;

  /// Lignes pour mode multiline (1 par défaut, >1 pour multiline).
  final int? maxLines;

  /// Limite de caractères (mode password : 8, PIN : 6, etc.).
  final int? maxLength;

  /// Champ obligatoire ? Ajoute « * » au label + validator non-vide.
  final bool required;

  /// Champ désactivé (lecture seule en visuel).
  final bool enabled;

  /// Auto-focus à l'affichage.
  final bool autofocus;

  const CuInput({
    super.key,
    required this.label,
    this.helper,
    this.errorText,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.type = CuInputType.text,
    this.controller,
    this.initialValue,
    this.validator,
    this.onChanged,
    this.textInputAction,
    this.maxLines,
    this.maxLength,
    this.required = false,
    this.enabled = true,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPassword = type == CuInputType.password;
    final fullLabel = required ? '$label *' : label;

    return Semantics(
      label: label,
      textField: true,
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        enabled: enabled,
        autofocus: autofocus,
        onChanged: onChanged,
        validator: _composeValidator(),
        obscureText: isPassword,
        keyboardType: _keyboardType(),
        inputFormatters: _formatters(),
        textInputAction: textInputAction,
        maxLines: type == CuInputType.multiline ? (maxLines ?? 3) : 1,
        maxLength: maxLength,
        autofillHints: _autofillHints(),
        decoration: InputDecoration(
          labelText: fullLabel,
          helperText: helper,
          hintText: hint,
          errorText: errorText,
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
          suffixIcon: suffix,
          // Padding tactile minimum confortable (mode gants pris en compte
          // au niveau theme via inputDecorationTheme.contentPadding).
          contentPadding: const EdgeInsets.symmetric(
            horizontal: CuSpacing.md,
            vertical: CuSpacing.sm,
          ),
        ),
      ),
    );
  }

  String? Function(String?)? _composeValidator() {
    if (!required && validator == null) return null;
    return (v) {
      if (required && (v == null || v.trim().isEmpty)) {
        return 'Ce champ est obligatoire';
      }
      if (validator != null) return validator!(v);
      return null;
    };
  }

  TextInputType _keyboardType() => switch (type) {
        CuInputType.email => TextInputType.emailAddress,
        CuInputType.number => TextInputType.number,
        CuInputType.decimal =>
          const TextInputType.numberWithOptions(decimal: true),
        CuInputType.phone => TextInputType.phone,
        CuInputType.multiline => TextInputType.multiline,
        CuInputType.password => TextInputType.visiblePassword,
        CuInputType.text => TextInputType.text,
      };

  List<TextInputFormatter>? _formatters() => switch (type) {
        CuInputType.number => [FilteringTextInputFormatter.digitsOnly],
        CuInputType.decimal => [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
          ],
        CuInputType.phone => [
            FilteringTextInputFormatter.allow(RegExp(r'[\d +\-]')),
          ],
        _ => null,
      };

  List<String>? _autofillHints() => switch (type) {
        CuInputType.email => const [AutofillHints.email],
        CuInputType.password => const [AutofillHints.password],
        CuInputType.phone => const [AutofillHints.telephoneNumber],
        _ => null,
      };
}

/// Composables courants pour [CuInput.validator]. Inspiré de Yup/Zod.
class CuValidators {
  CuValidators._();

  /// Combine plusieurs validators. Le 1er qui échoue gagne.
  static String? Function(String?) compose(
      List<String? Function(String?)> validators) {
    return (v) {
      for (final fn in validators) {
        final err = fn(v);
        if (err != null) return err;
      }
      return null;
    };
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : 'Email invalide';
  }

  static String? Function(String?) minLength(int n) =>
      (v) => (v == null || v.length < n) ? '$n caractères minimum' : null;

  static String? Function(String?) maxLength(int n) =>
      (v) => (v != null && v.length > n) ? '$n caractères maximum' : null;

  /// Décimal positif (ex. poids). Accepte virgule ou point.
  static String? Function(String?) decimal({double? min, double? max}) {
    return (v) {
      if (v == null || v.trim().isEmpty) return null;
      final parsed = double.tryParse(v.replaceAll(',', '.'));
      if (parsed == null) return 'Nombre invalide';
      if (min != null && parsed < min) return 'Doit être ≥ $min';
      if (max != null && parsed > max) return 'Doit être ≤ $max';
      return null;
    };
  }

  /// Entier positif.
  static String? Function(String?) integer({int? min, int? max}) {
    return (v) {
      if (v == null || v.trim().isEmpty) return null;
      final parsed = int.tryParse(v);
      if (parsed == null) return 'Nombre entier invalide';
      if (min != null && parsed < min) return 'Doit être ≥ $min';
      if (max != null && parsed > max) return 'Doit être ≤ $max';
      return null;
    };
  }
}

/// Couleur "danger" exposée pour les bordures custom — utile aux écrans
/// qui veulent imiter le style erreur sans utiliser un Form.
const Color cuInputErrorColor = CuColors.danger;
