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
import '../../core/utils/responsive.dart';
import '../common/app_animations.dart';
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
      data: (chats) => chats.any((c) => c.unread),
      orElse: () => false,
    );

    return shopState.when(
      data: (shop) {
        void onSelect(int i) => ref.read(navigationIndexProvider.notifier).setIndex(i);

        if (Responsive.useNavRail(context)) {
          return Scaffold(
            body: Row(
              children: [
                _SideNavRail(
                  currentIndex: currentIndex,
                  hasUnread: hasUnread,
                  isExtended: Responsive.useExtendedRail(context),
                  onSelect: onSelect,
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: FadeIndexedStack(index: currentIndex, children: _screens),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: FadeIndexedStack(index: currentIndex, children: _screens),
          bottomNavigationBar: _FloatingNavBar(
            currentIndex: currentIndex,
            hasUnread: hasUnread,
            onSelect: onSelect,
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
              Text('Loading storefront…', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error),
                  const SizedBox(height: 16),
                  const Text('Failed to load shop details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
                    ),
                    child: Text(error.toString(), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.textSecondary)),
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
                        onPressed: () async => ref.read(authProvider.notifier).logout(),
                        icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                        label: const Text('Logout', style: TextStyle(color: AppColors.error)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
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

// ─── Side Navigation Rail (tablets) ─────────────────────────────────────────

class _SideNavRail extends StatelessWidget {
  final int currentIndex;
  final bool hasUnread;
  final bool isExtended;
  final void Function(int) onSelect;

  const _SideNavRail({
    required this.currentIndex,
    required this.hasUnread,
    required this.isExtended,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onSelect,
      extended: isExtended,
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      selectedIconTheme: const IconThemeData(color: Colors.white, size: 22),
      unselectedIconTheme: IconThemeData(
        color: isDark ? Colors.white38 : AppColors.textHint,
        size: 22,
      ),
      selectedLabelTextStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w700,
        fontSize: 12,
        color: AppColors.primary,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w500,
        fontSize: 12,
        color: isDark ? Colors.white38 : AppColors.textHint,
      ),
      indicatorColor: AppColors.primary,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      minWidth: 72,
      minExtendedWidth: 200,
      destinations: [
        const NavigationRailDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view_rounded),
          label: Text('Home'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2_rounded),
          label: Text('Products'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.local_offer_outlined),
          selectedIcon: Icon(Icons.local_offer_rounded),
          label: Text('Offers'),
        ),
        NavigationRailDestination(
          icon: Badge(
            isLabelVisible: hasUnread,
            smallSize: 7,
            child: const Icon(Icons.chat_bubble_outline_rounded),
          ),
          selectedIcon: const Icon(Icons.chat_bubble_rounded),
          label: const Text('Chats'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: Text('Profile'),
        ),
      ],
    );
  }
}

// ─── Floating Navigation Bar (phones) ────────────────────────────────────────

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final bool hasUnread;
  final void Function(int) onSelect;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.hasUnread,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      color: scaffoldBg,
      padding: EdgeInsets.fromLTRB(16, 6, 16, bottomPad > 0 ? bottomPad + 4 : 14),
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: navBg,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.10),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _NavTab(index: 0, active: Icons.grid_view_rounded, inactive: Icons.grid_view_outlined, label: 'Home', ci: currentIndex, onTap: onSelect),
            _NavTab(index: 1, active: Icons.inventory_2_rounded, inactive: Icons.inventory_2_outlined, label: 'Products', ci: currentIndex, onTap: onSelect),
            _NavTab(index: 2, active: Icons.local_offer_rounded, inactive: Icons.local_offer_outlined, label: 'Offers', ci: currentIndex, onTap: onSelect),
            _NavTab(index: 3, active: Icons.chat_bubble_rounded, inactive: Icons.chat_bubble_outline_rounded, label: 'Chats', ci: currentIndex, onTap: onSelect, badge: hasUnread),
            _NavTab(index: 4, active: Icons.person_rounded, inactive: Icons.person_outline_rounded, label: 'Profile', ci: currentIndex, onTap: onSelect),
          ],
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final int index;
  final int ci; // currentIndex
  final IconData active;
  final IconData inactive;
  final String label;
  final bool badge;
  final void Function(int) onTap;

  const _NavTab({
    required this.index,
    required this.ci,
    required this.active,
    required this.inactive,
    required this.label,
    required this.onTap,
    this.badge = false,
  });

  bool get _sel => index == ci;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ghostColor = isDark ? Colors.white30 : AppColors.textHint;
    final labelColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 62,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 270),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _sel ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Badge(
                  isLabelVisible: badge && !_sel,
                  smallSize: 7,
                  child: Icon(
                    _sel ? active : inactive,
                    size: 20,
                    color: _sel ? Colors.white : ghostColor,
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 270),
                curve: Curves.easeOutCubic,
                child: _sel
                    ? Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: labelColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                            height: 1,
                          ),
                          maxLines: 1,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
