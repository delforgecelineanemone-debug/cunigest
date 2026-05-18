// CuPageRoute — Transition de page CuniUI
// Slide léger (4 % depuis la droite) + fade · 280 ms easeInOutCubic

import 'package:flutter/material.dart';

class CuPageRoute<T> extends PageRouteBuilder<T> {
  CuPageRoute({required WidgetBuilder builder, super.settings})
      : super(
          pageBuilder: (context, _, __) => builder(context),
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (context, animation, _, child) {
            final slide = animation.drive(
              Tween(begin: const Offset(0.04, 0.0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeInOutCubic)),
            );
            final fade = animation.drive(
              Tween(begin: 0.0, end: 1.0)
                  .chain(CurveTween(curve: Curves.easeIn)),
            );
            return FadeTransition(
              opacity: fade,
              child: SlideTransition(position: slide, child: child),
            );
          },
        );
}
