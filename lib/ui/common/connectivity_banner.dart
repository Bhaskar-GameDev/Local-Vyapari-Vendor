import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/connectivity_provider.dart';

/// Wraps [child] and overlays an animated banner at the top of the screen
/// whenever the device loses or regains internet connectivity.
class ConnectivityBanner extends ConsumerStatefulWidget {
  final Widget child;

  const ConnectivityBanner({super.key, required this.child});

  @override
  ConsumerState<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends ConsumerState<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  bool _showingBackOnline = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onConnectivityChanged(bool? previous, bool current) {
    if (previous == null) {
      // Initial emission — silently show banner if already offline.
      if (!current) _controller.forward();
      return;
    }
    if (previous == current) return;

    if (!current) {
      // Just went offline.
      _hideTimer?.cancel();
      setState(() => _showingBackOnline = false);
      _controller.forward();
    } else {
      // Just came back online.
      setState(() => _showingBackOnline = true);
      _controller.forward();
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(seconds: 2), _hideBanner);
    }
  }

  void _hideBanner() {
    _controller.reverse().then((_) {
      if (mounted) setState(() => _showingBackOnline = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(isOnlineProvider, _onConnectivityChanged);

    final isOnline = ref.watch(isOnlineProvider);
    final visible = !isOnline || _showingBackOnline;

    return Stack(
      children: [
        widget.child,
        if (visible)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _slide,
              child: FadeTransition(
                opacity: _fade,
                child: _BannerContent(isBackOnline: _showingBackOnline),
              ),
            ),
          ),
      ],
    );
  }
}

class _BannerContent extends StatelessWidget {
  final bool isBackOnline;

  const _BannerContent({required this.isBackOnline});

  @override
  Widget build(BuildContext context) {
    final isOnlineBanner = isBackOnline;
    final color = isOnlineBanner
        ? const Color(0xFF16A34A) // green-600
        : const Color(0xFFB91C1C); // red-700

    return Material(
      color: color,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isOnlineBanner ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                color: Colors.white,
                size: 15,
              ),
              const SizedBox(width: 8),
              Text(
                isOnlineBanner ? 'Back online' : 'No internet connection',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
              if (!isOnlineBanner) ...[
                const SizedBox(width: 6),
                const Text(
                  '· Offline mode',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
