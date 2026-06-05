/// Reusable skeleton-screen building blocks with an animated shimmer.
///
/// Prefer these over a [CircularProgressIndicator] for content that is being
/// fetched: a skeleton preserves the eventual layout, so the page doesn't jump
/// when data arrives and the wait feels shorter.
///
/// Typical use renders a list of [SkeletonCard]s during the loading branch of
/// an `AsyncValue`:
///
/// ```dart
/// state.when(
///   data: (items) => _list(items),
///   loading: () => const SkeletonList(),
///   error: (e, _) => ErrorView(error: e),
/// );
/// ```
///
/// Compose [SkeletonBox] / [SkeletonCircle] inside a single [Skeleton] wrapper
/// for custom layouts — keep the wrapper high in the tree so the shimmer sweep
/// stays in sync across all the placeholder shapes.
library;

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

/// The shimmer greys used app-wide. Matches the values the per-screen loaders
/// hand-rolled before this component existed.
const Color _kShimmerBase = Color(0xFFE0E0E0); // grey[300]
const Color _kShimmerHighlight = Color(0xFFF5F5F5); // grey[100]

/// Wraps [child] in the standard animated shimmer. Put the actual placeholder
/// shapes ([SkeletonBox], [SkeletonCircle]) inside it.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _kShimmerBase,
      highlightColor: _kShimmerHighlight,
      child: child,
    );
  }
}

/// A solid rounded rectangle placeholder (text line, image, button…).
///
/// The colour is irrelevant — the parent [Skeleton] paints the shimmer over it
/// — so it is always white, which is what the shimmer gradient expects.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = AppRadius.xs,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A circular placeholder — e.g. an avatar.
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// A single card-row skeleton: an avatar circle plus two stacked text lines
/// (a shorter title and a longer subtitle) — the shape of our list tiles.
///
/// Already wrapped in its own [Skeleton], so it can be dropped straight into a
/// list builder.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    this.avatarSize = 48,
    this.padding = const EdgeInsets.symmetric(vertical: AppSpacing.sm),
  });

  final double avatarSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            SkeletonCircle(size: avatarSize),
            AppSpacing.horizontalMd,
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 120, height: 16),
                  AppSpacing.verticalXs,
                  SkeletonBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders [itemCount] [SkeletonCard]s in a non-scrolling-aware [ListView] for
/// the fetching state of a list screen. Divider-separated to mirror real tiles.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    this.avatarSize = 48,
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (context, _) => Divider(
        color: Theme.of(context).colorScheme.outlineVariant,
        height: 1,
      ),
      itemBuilder: (context, _) => SkeletonCard(avatarSize: avatarSize),
    );
  }
}
