import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';

/// Centers [child] horizontally and caps its width on wide screens (tablets),
/// while staying full-width on phones.
///
/// Wrap a screen's scrollable body with this so forms, lists and content don't
/// stretch edge-to-edge on large displays. Pairs with the existing [Responsive]
/// breakpoint helper used elsewhere in the app.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  /// Content width cap (default [AppDimensions.maxContentWidth] = 600).
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = AppDimensions.maxContentWidth,
    this.padding,
  });

  /// Narrower cap tuned for forms ([AppDimensions.maxFormWidth] = 480):
  /// sign-in, shop setup, MFA, etc.
  const ResponsiveCenter.form({
    super.key,
    required this.child,
    this.padding,
  }) : maxWidth = AppDimensions.maxFormWidth;

  @override
  Widget build(BuildContext context) {
    Widget content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    // topCenter keeps scroll content anchored to the top while centering it
    // horizontally on screens wider than [maxWidth].
    return Align(alignment: Alignment.topCenter, child: content);
  }
}
