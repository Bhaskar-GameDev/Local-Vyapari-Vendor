import 'package:flutter/material.dart';

/// Central breakpoint helper.
///
/// Uses `shortestSide` for phone-vs-tablet detection so a phone in landscape
/// (wide but short) still gets the phone layout.
class Responsive {
  Responsive._();

  // ── Raw measurements ─────────────────────────────────────────────────────

  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;
  static double shortestSide(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide;

  // ── Device tier ──────────────────────────────────────────────────────────

  /// Phone: shortestSide < 600
  static bool isPhone(BuildContext context) => shortestSide(context) < 600;

  /// Tablet: shortestSide >= 600
  static bool isTablet(BuildContext context) => shortestSide(context) >= 600;

  /// Large tablet: shortestSide >= 840
  static bool isLargeTablet(BuildContext context) =>
      shortestSide(context) >= 840;

  // ── Navigation ───────────────────────────────────────────────────────────

  /// Use NavigationRail instead of bottom nav bar.
  static bool useNavRail(BuildContext context) => isTablet(context);

  /// Use an extended (full-label) NavigationRail.
  static bool useExtendedRail(BuildContext context) => isLargeTablet(context);

  // ── Spacing ──────────────────────────────────────────────────────────────

  static double horizontalPadding(BuildContext context) {
    final w = width(context);
    if (w >= 1024) return 32;
    if (w >= 720) return 28;
    if (w >= 600) return 24;
    return 16;
  }

  // ── Grid columns ─────────────────────────────────────────────────────────

  /// Columns for the products grid.
  static int productGridColumns(BuildContext context) {
    final w = width(context);
    if (w >= 1200) return 4;
    if (w >= 900) return 3;
    if (w >= 600) return 2;
    return MediaQuery.orientationOf(context) == Orientation.landscape ? 3 : 2;
  }

  /// Columns for the offers grid (1 = list, 2 = grid).
  static int offerGridColumns(BuildContext context) => isTablet(context) ? 2 : 1;

  // ── Dashboard ────────────────────────────────────────────────────────────

  /// Show stat tiles in a 2×2 grid rather than horizontal scroll.
  static bool useStatsGrid(BuildContext context) => isTablet(context);

  /// Height of the analytics chart.
  static double chartHeight(BuildContext context) =>
      isTablet(context) ? 210 : 160;

  /// Scale factor for hero-card text (1.0 on phone, 1.15 on tablet).
  static double heroTextScale(BuildContext context) =>
      isTablet(context) ? 1.15 : 1.0;
}
