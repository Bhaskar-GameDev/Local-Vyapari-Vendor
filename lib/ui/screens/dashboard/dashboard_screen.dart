import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/offer_model.dart';
import '../../../data/models/shop_model.dart';
import '../../../domain/providers/product_provider.dart';
import '../../../domain/providers/offer_provider.dart';
import '../../../domain/providers/shop_provider.dart';
import '../../common/app_animations.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsState = ref.watch(productsProvider);
    final offersState = ref.watch(offersProvider);
    final shopState = ref.watch(shopProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.storefront),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(context, shopState),
            const SizedBox(height: 24),
            FadeInSlide(
              duration: const Duration(milliseconds: 500),
              delay: const Duration(milliseconds: 150),
              slideOffset: 10,
              child: Text('Quick Stats', style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 16),
            _buildStatsGrid(productsState, offersState),
            const SizedBox(height: 24),
            FadeInSlide(
              duration: const Duration(milliseconds: 500),
              delay: const Duration(milliseconds: 400),
              slideOffset: 10,
              child: Text('Low Stock Alerts', style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 16),
            _buildLowStockList(productsState),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context, AsyncValue<ShopModel?> shopState) {
    return FadeInSlide(
      duration: const Duration(milliseconds: 600),
      slideOffset: 20,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shopState.when(
                      data: (shop) => 'Hello, ${shop?.name ?? 'Vendor'}',
                      loading: () => 'Loading...',
                      error: (_, __) => 'Hello, Vendor',
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your shop is live and visible to 1,200 nearby users.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: const Icon(Icons.rocket_launch, color: Colors.white, size: 30),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(AsyncValue<List<ProductModel>> productsState, AsyncValue<List<OfferModel>> offersState) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        FadeInSlide(
          duration: const Duration(milliseconds: 500),
          delay: const Duration(milliseconds: 200),
          slideOffset: 16,
          child: _StatCard(
            title: 'Active Products',
            value: productsState.maybeWhen(data: (list) => list.length.toString(), orElse: () => '0'),
            isLoading: productsState.isLoading,
            icon: Icons.inventory_2,
            color: AppColors.info,
          ),
        ),
        FadeInSlide(
          duration: const Duration(milliseconds: 500),
          delay: const Duration(milliseconds: 250),
          slideOffset: 16,
          child: _StatCard(
            title: 'Live Offers',
            value: offersState.maybeWhen(data: (list) => list.length.toString(), orElse: () => '0'),
            isLoading: offersState.isLoading,
            icon: Icons.local_offer,
            color: AppColors.warning,
          ),
        ),
        const FadeInSlide(
          duration: Duration(milliseconds: 500),
          delay: Duration(milliseconds: 300),
          slideOffset: 16,
          child: _StatCard(
            title: 'Today Views',
            value: '328',
            icon: Icons.visibility,
            color: AppColors.accent,
          ),
        ),
        const FadeInSlide(
          duration: Duration(milliseconds: 500),
          delay: Duration(milliseconds: 350),
          slideOffset: 16,
          child: _StatCard(
            title: 'Profile Clicks',
            value: '45',
            icon: Icons.touch_app,
            color: AppColors.primaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildLowStockList(AsyncValue<List<ProductModel>> productsState) {
    if (productsState.isLoading) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 2,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                title: Container(
                  height: 14,
                  color: Colors.white,
                  margin: const EdgeInsets.only(right: 120),
                ),
                subtitle: Container(
                  height: 10,
                  color: Colors.white,
                  margin: const EdgeInsets.only(right: 180, top: 6),
                ),
              ),
            ),
          );
        },
      );
    }
    if (productsState.hasError) return const Text('Error loading inventory.');
    
    final allProducts = (productsState.asData?.value ?? []);
    // Filter products with stock < 5
    final lowStock = allProducts.where((p) => p.stockQuantity < 5).toList();

    if (lowStock.isEmpty) {
      return const FadeInSlide(
        duration: Duration(milliseconds: 500),
        delay: Duration(milliseconds: 450),
        slideOffset: 12,
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Inventory is healthy! No low stock alerts.'),
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
          duration: const Duration(milliseconds: 500),
          delay: Duration(milliseconds: 450 + (index * 100)),
          slideOffset: 16,
          child: ScaleOnTap(
            onTap: () {},
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                ),
                title: Text(product.name),
                subtitle: Text('Only ${product.stockQuantity} left in stock'),
                trailing: TextButton(
                  onPressed: () {},
                  child: const Text('Update'),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isLoading;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleOnTap(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                if (isLoading)
                  Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                      width: 40,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  )
                else
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
