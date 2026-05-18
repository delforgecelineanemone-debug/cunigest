import 'package:flutter/material.dart';
import '../../utils/breakpoints.dart';

/// Centre le contenu et limite sa largeur sur tablette/desktop.
/// Sur mobile (< 600px), renvoie [child] tel quel (no-op).
///
/// Usage direct :
/// ```dart
/// Scaffold(body: CuPageWrapper(child: ListView(...)))
/// ```
///
/// Ou via l'extension `.responsive()` :
/// ```dart
/// Scaffold(body: ListView(...).responsive())
/// ```
class CuPageWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const CuPageWrapper({
    super.key,
    required this.child,
    this.maxWidth = 900,
  });

  @override
  Widget build(BuildContext context) {
    if (!context.isWide) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

extension WidgetResponsive on Widget {
  /// Wrappe ce widget dans un [CuPageWrapper] (no-op sur mobile).
  /// À utiliser sur le `body` d'un Scaffold pour limiter la largeur sur tablette.
  Widget responsive({double maxWidth = 900}) =>
      CuPageWrapper(maxWidth: maxWidth, child: this);
}
