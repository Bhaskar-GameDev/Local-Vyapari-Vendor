import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers/shop_provider.dart';
import '../../domain/providers/auth_provider.dart';
import 'dashboard/dashboard_screen.dart';
import 'products/products_list_screen.dart';
import 'offers/offers_list_screen.dart';
import 'profile/profile_screen.dart';
import 'shop/setup_shop_screen.dart';
import 'auth/login_screen.dart';
import '../../core/theme/app_colors.dart';

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const ProductsListScreen(),
    const OffersListScreen(),
    const Center(child: Text('Notifications')), // Stub
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final shopState = ref.watch(shopProvider);

    return shopState.when(
      data: (shop) {
        if (shop == null) {
          // If shop is null (merchant signs up for the first time), redirect to SetupShopScreen
          return const SetupShopScreen();
        }

        // Show main navigation when shop profile is completed
        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.inventory_2_rounded), label: 'Products'),
                BottomNavigationBarItem(icon: Icon(Icons.local_offer_rounded), label: 'Offers'),
                BottomNavigationBarItem(icon: Icon(Icons.notifications_rounded), label: 'Alerts'),
                BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading storefront...',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load shop details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withOpacity(0.15)),
                    ),
                    child: Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => ref.read(shopProvider.notifier).loadShopProfile(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await ref.read(authProvider.notifier).logout();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                        icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                        label: const Text('Logout', style: TextStyle(color: AppColors.error)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
