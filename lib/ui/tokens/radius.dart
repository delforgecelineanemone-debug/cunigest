import 'package:flutter/material.dart';

abstract final class CuRadius {
  static const double sm = 8;    // chips, badges
  static const double md = 12;   // cards, inputs
  static const double lg = 20;   // sheets, modals
  static const double full = 999; // pills

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get fullAll => BorderRadius.circular(full);

  static RoundedRectangleBorder get smShape =>
      RoundedRectangleBorder(borderRadius: smAll);
  static RoundedRectangleBorder get mdShape =>
      RoundedRectangleBorder(borderRadius: mdAll);
  static RoundedRectangleBorder get lgShape =>
      RoundedRectangleBorder(borderRadius: lgAll);
}
