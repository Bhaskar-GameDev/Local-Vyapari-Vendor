import 'package:flutter/material.dart';

class AppSpacing {
  // Spacing Tokens
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 40.0;

  // Vertical Spacing Helpers
  static const Widget verticalXs = SizedBox(height: xs);
  static const Widget verticalSm = SizedBox(height: sm);
  static const Widget verticalMd = SizedBox(height: md);
  static const Widget verticalLg = SizedBox(height: lg);
  static const Widget verticalXl = SizedBox(height: xl);
  static const Widget verticalXxl = SizedBox(height: xxl);

  // Horizontal Spacing Helpers
  static const Widget horizontalXs = SizedBox(width: xs);
  static const Widget horizontalSm = SizedBox(width: sm);
  static const Widget horizontalMd = SizedBox(width: md);
  static const Widget horizontalLg = SizedBox(width: lg);
  static const Widget horizontalXl = SizedBox(width: xl);
  static const Widget horizontalXxl = SizedBox(width: xxl);
}
