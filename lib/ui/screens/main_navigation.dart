import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers/shop_provider.dart';
import '../../domain/providers/auth_provider.dart';
import 'dashboard/dashboard_screen.dart';
import 'products/products_list_screen.dart';
import 'offers/offers_list_screen.dart';
import 'profile/profile_screen.dart';
import 'chat/chats_list_screen.dart';
import '../../core/theme/app_colors.dart';
import '../common/app_animations.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/providers/navigation_provider.dart';
import '../../domain/providers/chat_provider.dart';

class MainNavigation extends ConsumerWidget {
  const MainNavigation({super.key});

  static const List<Widget> _screens = [
    DashboardScreen(),
    ProductsListScreen(),
    OffersListScreen(),
    ChatsListScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopState = ref.watch(shopProvider);
    final currentIndex = ref.watch(navigationIndexProvider);
    
    final chatsState = ref.watch(vendorChatsProvider);
    final hasUnread = chatsState.maybeWhen(
      data: (chats) => chats.any((chat) => chat.unread),
      orElse: () => false,
    );

    return shopState.when(
      data: (shop) {
        // Show main navigation when shop profile is completed (delegated redirect to GoRouter)
        return Scaffold(
          body: FadeIndexedStack(
            index: currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: Container(
            height: AppDimensions.bottomNavBarHeight,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: (index) => ref.read(navigationIndexProvider.notifier).setIndex(index),
              selectedFontSize: 11,
              unselectedFontSize: 11,
              iconSize: 20,
              elevation: 0,
              items: [
                const BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
                const BottomNavigationBarItem(icon: Icon(Icons.inventory_2_rounded), label: 'Products'),
                const BottomNavigationBarItem(icon: Icon(Icons.local_offer_rounded), label: 'Offers'),
                BottomNavigationBarItem(
                  icon: Badge(
                    isLabelVisible: hasUnread,
                    child: const Icon(Icons.chat_bubble_rounded),
                  ),
                  label: 'Chats',
                ),
                const BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
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
                        onPressed: () => ref.invalidate(shopProvider),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await ref.read(authProvider.notifier).logout();
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
