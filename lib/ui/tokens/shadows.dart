import 'package:flutter/material.dart';

abstract final class CuShadows {
  static const List<BoxShadow> none = [];

  /// Ombre légère — cards standard
  static const List<BoxShadow> level1 = [
    BoxShadow(
      color: Color(0x14000000), // 8% noir
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Ombre prononcée — sheets, modals, FAB
  static const List<BoxShadow> level2 = [
    BoxShadow(
      color: Color(0x1F000000), // 12% noir
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];
}
