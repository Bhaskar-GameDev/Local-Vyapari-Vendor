import 'package:flutter/material.dart';

/// A widget that animates its child with a fade-in and vertical/horizontal slide-in on mount.
/// Great for staggered animations in grids and lists by using different [delay] offsets.
class FadeInSlide extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double slideOffset;
  final Axis direction;

  const FadeInSlide({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
    this.slideOffset = 24.0,
    this.direction = Axis.vertical,
  });

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide> with SingleTickerProviderStateMixin {
  static final Set<Key> _animatedKeys = {};
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: widget.direction == Axis.vertical
          ? Offset(0.0, widget.slideOffset / 100.0)
          : Offset(widget.slideOffset / 100.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

    final key = widget.key;
    if (key != null && _animatedKeys.contains(key)) {
      _controller.value = 1.0;
    } else {
      if (key != null) {
        _animatedKeys.add(key);
      }
      if (widget.delay == Duration.zero) {
        _controller.forward();
      } else {
        Future.delayed(widget.delay, () {
          if (mounted) {
            _controller.forward();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _animatedKeys.remove(widget.key);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

/// A widget that scales down slightly when pressed and scales back to normal when released,
/// providing a tactile, premium click feedback.
class ScaleOnTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final Duration duration;

  const ScaleOnTap({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.96,
    this.duration = const Duration(milliseconds: 120),
  });

  @override
  State<ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<ScaleOnTap> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleFactor).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget scaleWidget = ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );

    return Listener(
      onPointerDown: (_) => _controller.forward(),
      onPointerUp: (_) => _controller.reverse(),
      onPointerCancel: (_) => _controller.reverse(),
      child: widget.onTap != null
          ? GestureDetector(
              onTap: widget.onTap,
              behavior: HitTestBehavior.opaque,
              child: scaleWidget,
            )
          : scaleWidget,
    );
  }
}

/// A state-preserving [IndexedStack] that performs a fade transition when switching tabs.
class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.97, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: IndexedStack(
          index: widget.index,
          children: widget.children,
        ),
      ),
    );
  }
}

/// Custom routing transition builders for smooth screen-to-screen animation flow.
class AppPageRoute {
  /// Fade through with scale — used for top-level navigation.
  /// Secondary animation dims + scales the underlying page when pushed away.
  static Route<T> fadeThrough<T>(Widget page, {RouteSettings? settings}) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final enterFade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        final enterScale = Tween<double>(begin: 0.94, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

        final exitFade = Tween<double>(begin: 1.0, end: 0.85)
            .animate(CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn));
        final exitScale = Tween<double>(begin: 1.0, end: 0.96)
            .animate(CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn));

        return FadeTransition(
          opacity: exitFade,
          child: ScaleTransition(
            scale: exitScale,
            child: FadeTransition(
              opacity: enterFade,
              child: ScaleTransition(
                scale: enterScale,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Slide up from bottom — used for action screens (create/edit forms).
  /// Secondary animation scales + dims this page when another pushes on top.
  static Route<T> slideUp<T>(Widget page, {RouteSettings? settings}) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final enterSlide = Tween<Offset>(
          begin: const Offset(0.0, 0.12),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutQuart,
          reverseCurve: Curves.easeInQuint,
        ));
        final enterFade = CurvedAnimation(parent: animation, curve: Curves.easeOut);

        final secScale = Tween<double>(begin: 1.0, end: 0.94)
            .animate(CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn));
        final secDim = Tween<double>(begin: 1.0, end: 0.78)
            .animate(CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn));

        return ScaleTransition(
          scale: secScale,
          child: FadeTransition(
            opacity: secDim,
            child: FadeTransition(
              opacity: enterFade,
              child: SlideTransition(
                position: enterSlide,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Slide in from the right — used for drill-down screens.
  /// Secondary animation creates an iOS-style parallax: this page drifts left
  /// when another page is pushed on top of it.
  static Route<T> slideRight<T>(Widget page, {RouteSettings? settings}) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final enterSlide = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ));

        // Parallax: slide left 30% + dim when pushed away
        final exitSlide = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.3, 0.0),
        ).animate(CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOut));
        final exitDim = Tween<double>(begin: 1.0, end: 0.85)
            .animate(CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn));

        return SlideTransition(
          position: exitSlide,
          child: FadeTransition(
            opacity: exitDim,
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(-6, 0),
                  ),
                ],
              ),
              child: SlideTransition(
                position: enterSlide,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Full-screen modal slide — used for forms that feel like a bottom sheet.
  /// Slides up from the very bottom with a spring-like curve.
  /// Secondary animation cards the background down and dims it.
  static Route<T> modal<T>(Widget page, {RouteSettings? settings}) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 460),
      reverseTransitionDuration: const Duration(milliseconds: 360),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final enterSlide = Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutQuint,
          reverseCurve: Curves.easeInQuint,
        ));

        final secScale = Tween<double>(begin: 1.0, end: 0.92)
            .animate(CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOut));
        final secDim = Tween<double>(begin: 1.0, end: 0.70)
            .animate(CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn));

        return ScaleTransition(
          scale: secScale,
          child: FadeTransition(
            opacity: secDim,
            child: SlideTransition(
              position: enterSlide,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
