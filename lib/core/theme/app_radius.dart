import 'package:flutter/material.dart';

class AppRadius {
  // Corner Radius Tokens
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;

  // BorderRadius Helpers
  static final BorderRadius borderXs = BorderRadius.circular(xs);
  static final BorderRadius borderSm = BorderRadius.circular(sm);
  static final BorderRadius borderMedium = BorderRadius.circular(md); // Requested name: borderMedium
  static final BorderRadius borderMd = BorderRadius.circular(md);
  static final BorderRadius borderLg = BorderRadius.circular(lg);
  static final BorderRadius borderXl = BorderRadius.circular(xl);
  static final BorderRadius borderXxl = BorderRadius.circular(xxl);

  // Radius Helpers
  static const Radius radiusXs = Radius.circular(xs);
  static const Radius radiusSm = Radius.circular(sm);
  static const Radius radiusMd = Radius.circular(md);
  static const Radius radiusLg = Radius.circular(lg);
  static const Radius radiusXl = Radius.circular(xl);
  static const Radius radiusXxl = Radius.circular(xxl);
}
