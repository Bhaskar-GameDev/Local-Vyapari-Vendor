import 'package:flutter/material.dart';

import '../../core/exceptions/error_handler.dart';
import '../../core/theme/app_colors.dart';

/// A like/favourite toggle with an *optimistic* UI update.
///
/// On tap it immediately flips the icon and adjusts the count, then runs
/// [onToggle] in the background. If [onToggle] throws (network/permission
/// failure), the previous state is restored and a [SnackBar] is shown — the
/// user never waits on the round-trip, and a failure is self-correcting.
///
/// State is owned locally (the Dart analog of React's `useState`) because a
/// like toggle is ephemeral per-widget UI state. [onToggle] receives the new
/// desired `liked` value and should persist it; it must throw on failure so the
/// rollback can fire. A null [onToggle] keeps the toggle purely local.
class LikeButton extends StatefulWidget {
  const LikeButton({
    super.key,
    this.initialLiked = false,
    this.initialCount = 0,
    this.onToggle,
    this.iconSize = 24,
  });

  final bool initialLiked;
  final int initialCount;

  /// Persists the new state. Throws to signal failure (triggers rollback).
  final Future<void> Function(bool liked)? onToggle;

  final double iconSize;

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  late bool _liked = widget.initialLiked;
  late int _count = widget.initialCount;

  /// True while an [onToggle] is in flight. Used to ignore rapid re-taps so a
  /// second tap can't race the rollback of the first.
  bool _inFlight = false;

  Future<void> _handleTap() async {
    if (_inFlight || widget.onToggle == null) {
      // No backend wired up — just flip locally.
      if (widget.onToggle == null) {
        setState(() {
          _liked = !_liked;
          _count += _liked ? 1 : -1;
        });
      }
      return;
    }

    // Snapshot for rollback, then apply the optimistic update up front.
    final prevLiked = _liked;
    final prevCount = _count;
    final next = !prevLiked;

    setState(() {
      _liked = next;
      _count += next ? 1 : -1;
      _inFlight = true;
    });

    try {
      await widget.onToggle!(next);
    } catch (e, st) {
      ErrorHandler.log(e, st);
      if (!mounted) return;
      // Revert to the pre-tap state.
      setState(() {
        _liked = prevLiked;
        _count = prevCount;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
    } finally {
      if (mounted) setState(() => _inFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _liked
                  ? AppColors.error
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: widget.iconSize,
            ),
            if (_count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$_count',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _liked
                      ? AppColors.error
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
