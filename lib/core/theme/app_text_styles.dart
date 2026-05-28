import 'package:flutter/material.dart';

/// Centralized Text Styles and Scaling Helpers
class AppTextStyles {
  /// Computes a responsive font size based on screen width relative to a base width (375.0),
  /// clamped between a minimum and maximum scaling factor to prevent layout clipping.
  static double getResponsiveFontSize(
    BuildContext context,
    double baseSize, {
    double minScale = 0.85,
    double maxScale = 1.15,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    // Standard phone baseline is 375.0
    final scaleFactor = (width / 375.0).clamp(minScale, maxScale);
    return baseSize * scaleFactor;
  }

  /// Extension-like helper to get standard scaled text styles
  static TextStyle getBodyLarge(BuildContext context) {
    return Theme.of(context).textTheme.bodyLarge!.copyWith(
          fontSize: getResponsiveFontSize(context, 16.0),
        );
  }

  static TextStyle getBodyMedium(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: getResponsiveFontSize(context, 14.0),
        );
  }

  static TextStyle getTitleLarge(BuildContext context) {
    return Theme.of(context).textTheme.titleLarge!.copyWith(
          fontSize: getResponsiveFontSize(context, 20.0),
        );
  }

  static TextStyle getHeadlineLarge(BuildContext context) {
    return Theme.of(context).textTheme.headlineLarge!.copyWith(
          fontSize: getResponsiveFontSize(context, 24.0),
        );
  }
}
