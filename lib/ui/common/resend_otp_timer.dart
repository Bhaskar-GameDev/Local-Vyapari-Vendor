import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A "Resend code" affordance that is disabled for [cooldown] after each send,
/// showing a live countdown, then becomes tappable.
///
/// Place it beneath an OTP input. [onResend] should re-trigger the send-OTP
/// call (which yields a fresh verificationId in the parent). The countdown
/// starts on mount (i.e. right after the first code is sent) and restarts on
/// every tap.
class ResendOtpTimer extends StatefulWidget {
  final VoidCallback onResend;
  final Duration cooldown;

  /// When false the control is inert (e.g. while a verify is in flight).
  final bool enabled;

  const ResendOtpTimer({
    super.key,
    required this.onResend,
    this.cooldown = const Duration(seconds: 30),
    this.enabled = true,
  });

  @override
  State<ResendOtpTimer> createState() => _ResendOtpTimerState();
}

class _ResendOtpTimerState extends State<ResendOtpTimer> {
  Timer? _timer;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    setState(() => _remaining = widget.cooldown.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _remaining--);
      if (_remaining <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTap() {
    if (_remaining > 0 || !widget.enabled) return;
    widget.onResend();
    _start();
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _remaining > 0;
    final canResend = !waiting && widget.enabled;
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: canResend ? _onTap : null,
        icon: Icon(
          Icons.refresh_rounded,
          size: 16,
          color: canResend ? AppColors.primary : AppColors.textSecondary,
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        label: Text(
          waiting ? 'Resend code in ${_remaining}s' : 'Resend code',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: canResend ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
