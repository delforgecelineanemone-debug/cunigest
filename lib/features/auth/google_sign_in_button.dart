// ──────────────────────────────────────────────────────────────
// Widget : bouton « Continuer avec Google » (V3.1)
// ──────────────────────────────────────────────────────────────
// Bouton large, premium, blanc à bordure subtile. Affiche l'icône
// Google officielle (couleurs vraies, pas d'unicode). Gère l'état
// busy automatiquement et expose un callback `onSuccess(result)`.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../services/auth/google_auth_service.dart';

class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({
    super.key,
    required this.onResult,
    this.label = 'Continuer avec Google',
    this.enabled = true,
  });

  /// Callback appelé avec le résultat (success / cancelled / error).
  /// L'appelant décide quoi faire : créer le compte local, naviguer, etc.
  final ValueChanged<GoogleAuthResult> onResult;

  final String label;
  final bool enabled;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _busy = false;

  Future<void> _onPressed() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await GoogleAuthService.instance.signIn();
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onResult(result);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1F1F1F) : Colors.white;
    final fg = isDark ? Colors.white : const Color(0xFF1F1F1F);
    final border = isDark ? Colors.white24 : const Color(0xFFDADCE0);

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: widget.enabled && !_busy ? _onPressed : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          side: BorderSide(color: border, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: _busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4285F4)),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _GoogleGlyph(),
                  const SizedBox(width: 12),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: fg,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Logo Google officiel "G" — 4 quadrants colorés.
/// Painter custom pour éviter de bundler une image.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;
    final stroke = w * 0.21;

    // Cercle "G" en 4 arcs colorés
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(center: center, radius: radius - stroke / 2);

    // Bleu : 3h → 12h (-90° à 0°)
    paint.color = _blue;
    canvas.drawArc(rect, -1.5708, 1.5708, false, paint);

    // Vert : 6h → 3h (90° à 0° — sweep négatif)
    paint.color = _green;
    canvas.drawArc(rect, 0, 1.5708, false, paint);

    // Jaune : 6h → 9h (90° à 180°)
    paint.color = _yellow;
    canvas.drawArc(rect, 1.5708, 1.5708, false, paint);

    // Rouge : 9h → 12h (180° → 270°)
    paint.color = _red;
    canvas.drawArc(rect, 3.1416, 1.5708, false, paint);

    // Barre horizontale du "G" (bleu)
    final barPaint = Paint()..color = _blue;
    final barRect = Rect.fromLTWH(
      center.dx,
      center.dy - stroke / 2,
      radius - stroke / 4,
      stroke,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}
