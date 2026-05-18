import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/providers/shop_provider.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/primary_button.dart';
import '../shop/setup_shop_screen.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopState = ref.watch(shopProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Shop Profile')),
      body: shopState.when(
        data: (shop) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.surfaceElevated,
                      backgroundImage: shop?.logoUrl != null ? NetworkImage(shop!.logoUrl!) : null,
                      child: shop?.logoUrl == null
                          ? const Icon(Icons.storefront, size: 50, color: AppColors.primary)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.edit, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildListTile('Shop Name', shop?.name ?? 'Not Set', Icons.business),
              _buildListTile('Description', shop?.description ?? 'Not Set', Icons.description),
              _buildListTile('Address', shop?.address ?? 'Not Set', Icons.location_on),
              _buildListTile('Phone', shop?.phone ?? 'Not Set', Icons.phone),
              const SizedBox(height: 32),
              PrimaryButton(
                text: 'Edit Profile',
                onPressed: () {
                  if (shop != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SetupShopScreen(existingShop: shop),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Logout'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildListTile(String title, String subtitle, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(title, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
