import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../domain/providers/product_provider.dart';
import '../../../domain/providers/review_provider.dart';
import '../../../data/models/product_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../common/app_animations.dart';
import 'add_product_screen.dart';
import '../reviews/product_reviews_screen.dart';

class ProductsListScreen extends ConsumerWidget {
  const ProductsListScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String productId, String productName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "$productName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(productsProvider.notifier).deleteProduct(productId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting product: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsState = ref.watch(productsProvider);
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Products'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
            child: productsState.when(
              data: (products) {
                if (products.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        'No products found. Add one!',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(productsProvider),
                  child: isTablet
                      ? GridView.builder(
                          padding: const EdgeInsets.all(AppDimensions.horizontalPadding),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isLandscape ? 3 : 2,
                            mainAxisSpacing: AppSpacing.md,
                            crossAxisSpacing: AppSpacing.md,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return _buildProductGridCard(context, ref, product, index);
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppDimensions.horizontalPadding),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return _buildProductListCard(context, ref, product, index);
                          },
                        ),
                );
              },
              loading: () => _buildShimmerLoading(isTablet, isLandscape),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text('Error: $error', style: const TextStyle(color: AppColors.error)),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_product_fab',
        onPressed: () {
          Navigator.push(
            context,
            AppPageRoute.slideUp(const AddProductScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }

  Widget _buildProductListCard(BuildContext context, WidgetRef ref, ProductModel product, int index) {
    final hasImage = product.images.isNotEmpty;
    final ratingDist = ref.watch(productRatingProvider(product.id));
    final rating = ratingDist.averageRating;
    final totalRatings = ratingDist.totalCount;
    
    return FadeInSlide(
      duration: const Duration(milliseconds: 400),
      delay: Duration(milliseconds: index * 50),
      slideOffset: 16,
      child: ScaleOnTap(
        onTap: () {
          Navigator.push(
            context,
            AppPageRoute.slideUp(AddProductScreen(existingProduct: product)),
          );
        },
        child: Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: AppRadius.borderSm,
                  child: Container(
                    width: 70,
                    height: 70,
                    color: AppColors.surfaceElevated,
                    child: hasImage
                        ? Image.network(
                            product.images.first,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
                          )
                        : const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 28),
                  ),
                ),
                AppSpacing.horizontalMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      AppSpacing.verticalXs,
                      Row(
                        children: [
                          Text(
                            product.category,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          AppSpacing.horizontalSm,
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: AppColors.textHint,
                              shape: BoxShape.circle,
                            ),
                          ),
                          AppSpacing.horizontalSm,
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (context) => ProductReviewsScreen(product: product),
                                ),
                              );
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: totalRatings > 0 ? Colors.amber : AppColors.textHint,
                                  size: 14,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  totalRatings > 0
                                      ? '${rating.toStringAsFixed(1)} ($totalRatings)'
                                      : 'No ratings',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: totalRatings > 0 ? AppColors.primary : AppColors.textSecondary,
                                    decoration: totalRatings > 0 ? TextDecoration.underline : TextDecoration.none,
                                  ),
                                ),
                                if (totalRatings > 0) ...[
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 12,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.verticalXs,
                      Row(
                        children: [
                          Text(
                            '₹${product.offerPrice ?? product.actualPrice}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14),
                          ),
                          if (product.offerPrice != null) ...[
                            AppSpacing.horizontalXs,
                            Text(
                              '₹${product.actualPrice}',
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: AppColors.textHint,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Switch(
                      value: product.isActive,
                      onChanged: (val) {
                        ref.read(productsProvider.notifier).toggleProductAvailability(product.id, val);
                      },
                      activeColor: AppColors.success,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                      onPressed: () => _confirmDelete(context, ref, product.id, product.name),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductGridCard(BuildContext context, WidgetRef ref, ProductModel product, int index) {
    final hasImage = product.images.isNotEmpty;
    final ratingDist = ref.watch(productRatingProvider(product.id));
    final rating = ratingDist.averageRating;
    final totalRatings = ratingDist.totalCount;

    return FadeInSlide(
      duration: const Duration(milliseconds: 400),
      delay: Duration(milliseconds: index * 50),
      slideOffset: 16,
      child: ScaleOnTap(
        onTap: () {
          Navigator.push(
            context,
            AppPageRoute.slideUp(AddProductScreen(existingProduct: product)),
          );
        },
        child: Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    hasImage
                        ? Image.network(
                            product.images.first,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 40),
                          )
                        : const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 40),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated.withOpacity(0.9),
                          borderRadius: AppRadius.borderXs,
                        ),
                        child: Text(
                          product.category,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (context) => ProductReviewsScreen(product: product),
                            ),
                          );
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: AppRadius.borderXs,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: totalRatings > 0 ? Colors.amber : Colors.white70,
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                totalRatings > 0
                                    ? '${rating.toStringAsFixed(1)} ($totalRatings)'
                                    : 'No ratings',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.verticalXs,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              '₹${product.offerPrice ?? product.actualPrice}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                            ),
                            if (product.offerPrice != null) ...[
                              AppSpacing.horizontalXs,
                              Text(
                                '₹${product.actualPrice}',
                                style: const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: AppColors.textHint,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          'Stock: ${product.stockQuantity}',
                          style: TextStyle(
                            fontSize: 11,
                            color: product.stockQuantity < 5 ? AppColors.error : AppColors.textSecondary,
                            fontWeight: product.stockQuantity < 5 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.verticalXs,
                    const Divider(height: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('Active', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            Transform.scale(
                              scale: 0.75,
                              child: Switch(
                                value: product.isActive,
                                onChanged: (val) {
                                  ref.read(productsProvider.notifier).toggleProductAvailability(product.id, val);
                                },
                                activeColor: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                          onPressed: () => _confirmDelete(context, ref, product.id, product.name),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(bool isTablet, bool isLandscape) {
    if (isTablet) {
      return GridView.builder(
        padding: const EdgeInsets.all(AppDimensions.horizontalPadding),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isLandscape ? 3 : 2,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.85,
        ),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Card(
              child: Container(
                color: Colors.white,
              ),
            ),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.horizontalPadding),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              height: 86,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}
