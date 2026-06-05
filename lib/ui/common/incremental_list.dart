import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Renders a long, already-in-memory list incrementally: only [pageSize] items
/// are shown at first, and another [pageSize] are revealed each time the user
/// scrolls within [bottomTriggerOffset] of the end — the Flutter analog of a
/// web `IntersectionObserver` infinite-scroll sentinel.
///
/// This is *client-side* paging. The full list is expected to already be in
/// memory (e.g. streamed from a Riverpod provider), so revealing more is
/// synchronous — there is no fetch and therefore no loading spinner. The point
/// is to cap how many items mount up front, keeping first paint and image
/// decoding cheap on large lists while leaving the source's realtime/offline
/// behaviour untouched.
///
/// [builder] receives the [ScrollController] to attach to the scrollable and
/// the current [visibleCount] to use as its `itemCount`. Because the visible
/// window is always `[0, visibleCount)`, an existing index-based `itemBuilder`
/// can be reused verbatim — only `itemCount` and `controller` change:
///
/// ```dart
/// IncrementalList(
///   itemCount: items.length,
///   builder: (context, controller, visibleCount) => ListView.builder(
///     controller: controller,
///     itemCount: visibleCount,
///     itemBuilder: (context, i) => Tile(items[i]),
///   ),
/// )
/// ```
class IncrementalList extends StatefulWidget {
  const IncrementalList({
    super.key,
    required this.itemCount,
    required this.builder,
    this.pageSize = 10,
    this.bottomTriggerOffset = 200,
  });

  /// Total number of items available in the backing list.
  final int itemCount;

  /// How many items to reveal per page.
  final int pageSize;

  /// Reveal the next page once the scroll offset is within this many pixels of
  /// the bottom.
  final double bottomTriggerOffset;

  final Widget Function(
    BuildContext context,
    ScrollController controller,
    int visibleCount,
  ) builder;

  @override
  State<IncrementalList> createState() => _IncrementalListState();
}

class _IncrementalListState extends State<IncrementalList> {
  final ScrollController _controller = ScrollController();
  late int _visibleCount = math.min(widget.pageSize, widget.itemCount);

  bool get _hasMore => _visibleCount < widget.itemCount;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    // The first page may not fill the viewport (so the user can't scroll to
    // trigger more); top up after the first layout until it does or runs out.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fillViewport());
  }

  @override
  void didUpdateWidget(IncrementalList old) {
    super.didUpdateWidget(old);
    // The backing list changed length (realtime update / refresh). Keep the
    // revealed window, but clamp it if the list shrank, and never drop below
    // one page when items exist.
    if (widget.itemCount != old.itemCount) {
      final floor = math.min(widget.pageSize, widget.itemCount);
      _visibleCount = _visibleCount.clamp(floor, widget.itemCount);
      WidgetsBinding.instance.addPostFrameCallback((_) => _fillViewport());
    }
  }

  void _onScroll() {
    if (!_controller.hasClients || !_hasMore) return;
    final position = _controller.position;
    if (position.pixels >=
        position.maxScrollExtent - widget.bottomTriggerOffset) {
      _revealMore();
    }
  }

  void _revealMore() {
    if (!_hasMore) return;
    setState(() {
      _visibleCount =
          math.min(_visibleCount + widget.pageSize, widget.itemCount);
    });
  }

  /// Reveals pages until the content overflows the viewport (and so becomes
  /// scrollable) or the list is exhausted — otherwise a short first page would
  /// strand the rest with no way to trigger a reveal.
  void _fillViewport() {
    if (!mounted || !_controller.hasClients || !_hasMore) return;
    final position = _controller.position;
    if (position.maxScrollExtent <= widget.bottomTriggerOffset) {
      _revealMore();
      WidgetsBinding.instance.addPostFrameCallback((_) => _fillViewport());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _controller, _visibleCount);
  }
}
