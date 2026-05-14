import 'dart:io';
import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/typography.dart';

/// Avatar lapin — affiche la photo si disponible, sinon initiales ou icône lapin.
/// Utilisé dans les listes, fiches et tiles.
class CuAvatar extends StatelessWidget {
  final String? photoPath;

  /// Bague ou label court affiché en fallback (ex: "F-238" → "F-2")
  final String? label;
  final Color? color;
  final double size;
  final bool round;

  const CuAvatar({
    super.key,
    this.photoPath,
    this.label,
    this.color,
    this.size = 48,
    this.round = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? CuColors.primary;
    final borderRadius =
        round ? BorderRadius.circular(size / 2) : CuRadius.mdAll;

    if (photoPath != null && photoPath!.isNotEmpty) {
      final file = File(photoPath!);
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(accent, borderRadius),
        ),
      );
    }

    return _placeholder(accent, borderRadius);
  }

  Widget _placeholder(Color accent, BorderRadius br) {
    final initials = _initials();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: br,
      ),
      alignment: Alignment.center,
      child: initials.isNotEmpty
          ? Text(
              initials,
              style: CuTypography.textTheme.labelMedium?.copyWith(
                fontSize: size * 0.28,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            )
          : Icon(Icons.pets, size: size * 0.48, color: accent),
    );
  }

  String _initials() {
    if (label == null || label!.isEmpty) return '';
    // Pour une bague type "F-238", on affiche "F-2" (4 chars max)
    return label!.length > 4 ? label!.substring(0, 4) : label!;
  }
}
