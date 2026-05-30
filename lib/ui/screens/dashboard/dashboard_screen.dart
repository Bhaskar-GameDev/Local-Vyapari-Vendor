import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/analytics_model.dart';
import '../../../domain/providers/product_provider.dart';
import '../../../domain/providers/offer_provider.dart';
import '../../../domain/providers/shop_provider.dart';
import '../../../domain/providers/analytics_provider.dart';
import '../../common/app_animations.dart';
import '../products/add_product_screen.dart';
import '../../../domain/providers/review_provider.dart';
import '../reviews/vendor_reviews_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopState = ref.watch(shopProvider);
    final shopName = shopState.maybeWhen(data: (s) => s?.name ?? 'Your Store', orElse: () => 'Your Store');

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_greeting(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: Theme.of(context).colorScheme.outline, height: 1)),
            Text(shopName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface, height: 1.3)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, size: 22),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              Responsive.horizontalPadding(context), 16,
              Responsive.horizontalPadding(context), 24,
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: AppDimensions.maxTabletContentWidth),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroCard(),
                  SizedBox(height: 22),
                  _StatsRow(),
                  SizedBox(height: 22),
                  _AnalyticsChartSection(),
                  SizedBox(height: 22),
                  _RatingsSection(),
                  SizedBox(height: 22),
                  _LowStockSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Hero Card ───────────────────────────────────────────────────────────────

class _HeroCard extends ConsumerWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopState = ref.watch(shopProvider);
    final analyticsState = ref.watch(analyticsProvider);
    final analytics = analyticsState.value ?? const AnalyticsModel();
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final todayStat = analytics.daily[todayStr] ?? const DailyStat();

    return FadeInSlide(
      duration: const Duration(milliseconds: 550),
      slideOffset: 20,
      child: shopState.maybeWhen(
        data: (shop) {
          final isOpen = shop?.isOpen ?? false;
          final ts = Responsive.heroTextScale(context);
          return Container(
            padding: EdgeInsets.all(Responsive.isTablet(context) ? 24 : 20),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusPill(isOpen: isOpen),
                    const Spacer(),
                    if (shop?.rating != null && (shop?.rating ?? 0) > 0)
                      _RatingChip(rating: shop!.rating!),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  shop?.name ?? 'Your Store',
                  style: TextStyle(color: Colors.white, fontSize: 22 * ts, fontWeight: FontWeight.w700, height: 1.2, fontFamily: 'Poppins'),
                ),
                if (shop?.address.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, color: Colors.white.withValues(alpha: 0.55), size: 12),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          shop!.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _HeroMiniStat(icon: Icons.visibility_outlined, value: '${todayStat.views}', label: "Today's views"),
                      _VertDivider(),
                      _HeroMiniStat(icon: Icons.ads_click_rounded, value: '${todayStat.clicks}', label: "Today's clicks"),
                      _VertDivider(),
                      _HeroMiniStat(icon: Icons.star_outline_rounded, value: '${shop?.totalReviews ?? 0}', label: 'Total reviews'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        orElse: () => Container(
          height: 180,
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
          child: const Center(child: CircularProgressIndicator(color: Colors.white38)),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isOpen;
  const _StatusPill({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              color: isOpen ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOpen ? 'Open' : 'Closed',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
          ),
        ],
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  final double rating;
  const _RatingChip({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 13),
          const SizedBox(width: 4),
          Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
        ],
      ),
    );
  }
}

class _HeroMiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _HeroMiniStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white54, size: 11),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Builder(builder: (ctx) {
              final s = Responsive.heroTextScale(ctx);
              return Text(value, style: TextStyle(color: Colors.white, fontSize: 20 * s, fontWeight: FontWeight.w700, height: 1, fontFamily: 'Poppins'));
            }),
          ],
        ),
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 0.7, height: 30, color: Colors.white.withValues(alpha: 0.2));
  }
}

// ─── Stats Row (horizontal scroll) ───────────────────────────────────────────

class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsState = ref.watch(productsProvider);
    final offersState = ref.watch(offersProvider);
    final analyticsState = ref.watch(analyticsProvider);
    final analytics = analyticsState.value ?? const AnalyticsModel();
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final todayStat = analytics.daily[todayStr] ?? const DailyStat();

    final stats = [
      _StatData(
        label: 'Products',
        value: productsState.maybeWhen(data: (l) => '${l.length}', orElse: () => '—'),
        icon: Icons.inventory_2_rounded,
        color: AppColors.info,
        loading: productsState.isLoading,
      ),
      _StatData(
        label: 'Live Offers',
        value: offersState.maybeWhen(data: (l) => '${l.length}', orElse: () => '—'),
        icon: Icons.local_offer_rounded,
        color: AppColors.warning,
        loading: offersState.isLoading,
      ),
      _StatData(
        label: 'Views Today',
        value: analyticsState.isLoading ? '—' : '${todayStat.views}',
        icon: Icons.visibility_rounded,
        color: AppColors.accent,
        loading: analyticsState.isLoading,
      ),
      _StatData(
        label: 'Total Clicks',
        value: analyticsState.isLoading ? '—' : '${analytics.totalClicks}',
        icon: Icons.ads_click_rounded,
        color: AppColors.primaryLight,
        loading: analyticsState.isLoading,
      ),
    ];

    final useGrid = Responsive.useStatsGrid(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FadeInSlide(
          duration: Duration(milliseconds: 400),
          delay: Duration(milliseconds: 80),
          slideOffset: 10,
          child: _SectionHeader(title: 'Overview'),
        ),
        const SizedBox(height: 10),
        if (useGrid)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.4,
            ),
            itemCount: stats.length,
            itemBuilder: (context, i) => FadeInSlide(
              key: ValueKey('stat_grid_$i'),
              duration: const Duration(milliseconds: 420),
              delay: Duration(milliseconds: 100 + i * 50),
              slideOffset: 12,
              child: _StatTile(data: stats[i], flexible: true),
            ),
          )
        else
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: stats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => FadeInSlide(
                key: ValueKey('stat_$i'),
                duration: const Duration(milliseconds: 420),
                delay: Duration(milliseconds: 120 + i * 55),
                slideOffset: 14,
                direction: Axis.horizontal,
                child: _StatTile(data: stats[i]),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool loading;
  const _StatData({required this.label, required this.value, required this.icon, required this.color, this.loading = false});
}

class _StatTile extends StatelessWidget {
  final _StatData data;
  /// When true the tile expands to fill its grid cell (no fixed width).
  final bool flexible;
  const _StatTile({required this.data, this.flexible = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return Container(
      width: flexible ? null : 116,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: data.color, width: 3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.055),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(data.icon, color: data.color, size: 17),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              data.loading
                  ? Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(width: 40, height: 26, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    )
                  : Text(data.value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textColor, height: 1, fontFamily: 'Poppins')),
              const SizedBox(height: 2),
              Text(data.label, style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white54 : AppColors.textSecondary, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Analytics Chart ──────────────────────────────────────────────────────────

class _AnalyticsChartSection extends ConsumerWidget {
  const _AnalyticsChartSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsState = ref.watch(analyticsProvider);
    final analytics = analyticsState.value ?? const AnalyticsModel();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A2E) : Colors.white;

    return FadeInSlide(
      duration: const Duration(milliseconds: 500),
      delay: const Duration(milliseconds: 200),
      slideOffset: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionHeader(title: 'Performance'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Text('7 days', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RepaintBoundary(child: _buildChart(context, analytics, bg, isDark)),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context, AnalyticsModel analytics, Color bg, bool isDark) {
    final last7Days = List.generate(7, (i) => DateTime.now().subtract(Duration(days: 6 - i)));
    final spotsViews = <FlSpot>[];
    final spotsClicks = <FlSpot>[];
    double maxVal = 5.0;

    for (int i = 0; i < last7Days.length; i++) {
      final dateStr = last7Days[i].toIso8601String().split('T')[0];
      final stat = analytics.daily[dateStr] ?? const DailyStat();
      spotsViews.add(FlSpot(i.toDouble(), stat.views.toDouble()));
      spotsClicks.add(FlSpot(i.toDouble(), stat.clicks.toDouble()));
      if (stat.views > maxVal) maxVal = stat.views.toDouble();
      if (stat.clicks > maxVal) maxVal = stat.clicks.toDouble();
    }

    final hasData = analytics.daily.values.any((s) => s.views > 0 || s.clicks > 0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.055), blurRadius: 14, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: isDark ? Colors.white10 : AppColors.border.withValues(alpha: 0.6), width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _LegendDot(color: AppColors.primary, label: 'Views'),
              SizedBox(width: 16),
              _LegendDot(color: AppColors.warning, label: 'Clicks'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: Responsive.chartHeight(context),
            child: !hasData
                ? Center(
                    child: Text('No traffic data yet.', style: TextStyle(color: isDark ? Colors.white38 : AppColors.textHint, fontSize: 13)),
                  )
                : LineChart(LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(color: isDark ? Colors.white10 : AppColors.border, strokeWidth: 0.7),
                    ),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (v, _) => v == v.toInt()
                              ? Text(v.toInt().toString(), style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : AppColors.textSecondary))
                              : const SizedBox(),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) {
                            final idx = v.toInt();
                            if (idx < 0 || idx >= last7Days.length) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(DateFormat('E').format(last7Days[idx]),
                                  style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : AppColors.textSecondary)),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0, maxX: 6, minY: 0, maxY: maxVal * 1.2,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spotsViews,
                        isCurved: true,
                        color: AppColors.primary,
                        barWidth: 2.5,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.07)),
                      ),
                      LineChartBarData(
                        spots: spotsClicks,
                        isCurved: true,
                        color: AppColors.warning,
                        barWidth: 2.5,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(show: true, color: AppColors.warning.withValues(alpha: 0.07)),
                      ),
                    ],
                  )),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

// ─── Ratings Section ─────────────────────────────────────────────────────────

class _RatingsSection extends ConsumerWidget {
  const _RatingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingDist = ref.watch(vendorRatingDistributionProvider);
    return FadeInSlide(
      duration: const Duration(milliseconds: 500),
      delay: const Duration(milliseconds: 260),
      slideOffset: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionHeader(title: 'Customer Ratings'),
              const Spacer(),
              if (ratingDist.totalCount > 0)
                Text('${ratingDist.totalCount} total', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
            ],
          ),
          const SizedBox(height: 12),
          RatingBreakdownWidget(distribution: ratingDist),
        ],
      ),
    );
  }
}

// ─── Low Stock Section ────────────────────────────────────────────────────────

class _LowStockSection extends ConsumerWidget {
  const _LowStockSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsState = ref.watch(productsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FadeInSlide(
          duration: Duration(milliseconds: 500),
          delay: Duration(milliseconds: 300),
          slideOffset: 10,
          child: _SectionHeader(title: 'Low Stock Alerts'),
        ),
        const SizedBox(height: 12),
        _buildLowStockList(context, productsState),
      ],
    );
  }
}

// ─── Shared section header ────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

// ─── Low stock list builder (top-level function) ──────────────────────────────

Widget _buildLowStockList(BuildContext context, AsyncValue<List<ProductModel>> productsState) {
  if (productsState.isLoading) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 2,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(height: 72, margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
      ),
    );
  }

  if (productsState.hasError) {
    return Text('Error loading inventory.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant));
  }

  final allProducts = productsState.asData?.value ?? [];
  final lowStock = allProducts.where((p) => p.stockQuantity < 5).toList();

  if (lowStock.isEmpty) {
    return FadeInSlide(
      duration: const Duration(milliseconds: 500),
      delay: const Duration(milliseconds: 350),
      slideOffset: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: AppColors.accent, size: 18),
            const SizedBox(width: 10),
            Text('All products are well-stocked.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  return ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: lowStock.length,
    itemBuilder: (context, index) {
      final product = lowStock[index];
      return FadeInSlide(
        duration: const Duration(milliseconds: 400),
        delay: Duration(milliseconds: 350 + index * 70),
        slideOffset: 14,
        child: ScaleOnTap(
          onTap: () => Navigator.push(context, AppPageRoute.slideRight<void>(AddProductScreen(existingProduct: product))),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A2E) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Theme.of(context).colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 1),
                      Text('Only ${product.stockQuantity} left', style: const TextStyle(color: AppColors.error, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.outline, size: 18),
              ],
            ),
          ),
        ),
      );
    },
  );
}
