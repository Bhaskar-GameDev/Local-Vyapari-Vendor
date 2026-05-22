import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../domain/providers/product_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/app_animations.dart';
import 'add_product_screen.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Products'),
        automaticallyImplyLeading: false,
      ),
      body: productsState.when(
        data: (products) {
          if (products.isEmpty) {
            return const Center(child: Text('No products found. Add one!'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(productsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return FadeInSlide(
                  duration: const Duration(milliseconds: 400),
                  delay: Duration(milliseconds: index * 60),
                  slideOffset: 16,
                  child: ScaleOnTap(
                    onTap: () {
                      Navigator.push(
                        context,
                        AppPageRoute.slideUp(AddProductScreen(existingProduct: product)),
                      );
                    },
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory_2, color: AppColors.primary),
                        ),
                        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${product.category} • ₹${product.actualPrice}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: product.isActive,
                              onChanged: (val) {
                                ref.read(productsProvider.notifier).toggleProductAvailability(product.id, val);
                              },
                              activeColor: AppColors.success,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.error),
                              onPressed: () => _confirmDelete(context, ref, product.id, product.name),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => _buildShimmerLoading(),
        error: (error, stack) => Center(child: Text('Error: $error')),
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

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              title: Container(
                height: 16,
                color: Colors.white,
                margin: const EdgeInsets.only(right: 80),
              ),
              subtitle: Container(
                height: 12,
                color: Colors.white,
                margin: const EdgeInsets.only(right: 140, top: 8),
              ),
            ),
          ),
        );
      },
    );
  }
}
