import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/providers/auth_provider.dart';
import '../../domain/providers/shop_provider.dart';
import '../../ui/screens/auth/login_screen.dart';
import '../../ui/screens/auth/register_screen.dart';
import '../../ui/screens/main_navigation.dart';
import '../../ui/screens/shop/setup_shop_screen.dart';
import '../../ui/screens/splash/splash_screen.dart';
import '../../ui/screens/chat/chat_screen.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(
      authStateProvider,
      (_, __) => notifyListeners(),
      onError: (err, stack) => notifyListeners(),
    );
    _ref.listen(
      shopProvider,
      (_, __) => notifyListeners(),
      onError: (err, stack) => notifyListeners(),
    );
    _ref.listen(
      userProfileProvider,
      (_, __) => notifyListeners(),
      onError: (err, stack) => notifyListeners(),
    );
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final appRouter = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);
  
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => buildFadeThroughPage(
          key: state.pageKey,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => buildFadeThroughPage(
          key: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => buildSlideRightPage(
          key: state.pageKey,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: '/setup-shop',
        pageBuilder: (context, state) => buildFadeThroughPage(
          key: state.pageKey,
          child: const SetupShopScreen(),
        ),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => buildFadeThroughPage(
          key: state.pageKey,
          child: const MainNavigation(),
        ),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) {
          final extra = state.extra as Map<dynamic, dynamic>?;
          final userId = extra?['userId']?.toString() ?? '';
          final userName = extra?['userName']?.toString() ?? '';
          return ChatScreen(
            userId: userId,
            userName: userName,
          );
        },
      ),
    ],
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final shopState = ref.read(shopProvider);
      final userProfileState = ref.read(userProfileProvider);

      if (authState.isLoading || shopState.isLoading) {
        return null;
      }

      final user = authState.value;
      final shop = shopState.value;
      final userProfile = userProfileState.value;

      final isLoggedIn = user != null;
      final isShopSetup = shop != null &&
          shop.address.isNotEmpty &&
          shop.latitude != null &&
          shop.longitude != null;

      final location = state.matchedLocation;

      // Allow splash screen to display and complete its intro sequences
      if (location == '/splash') {
        return null;
      }

      final isPublicRoute = location == '/login' || location == '/register';

      if (!isLoggedIn) {
        if (!isPublicRoute) {
          return '/login';
        }
        return null;
      }

      // Check account status (gating for banned/suspended accounts)
      if (userProfileState.hasValue && userProfile != null) {
        final status = userProfile['status']?.toString();
        if (status == 'suspended' || status == 'banned') {
          // Immediately log out suspended user
          ref.read(authRepositoryProvider).logout();
          return '/login';
        }

        // Check if user is a merchant (role validation)
        final roles = userProfile['roles'] as Map?;
        final isMerchant = roles?['merchant'] == true;
        if (!isMerchant) {
          // Merchant role missing, redirect to onboarding/registration
          if (location != '/setup-shop') {
            return '/setup-shop';
          }
          return null;
        }
      }

      // User is logged in and is a merchant, check if shop is setup
      if (!isShopSetup) {
        if (location != '/setup-shop') {
          return '/setup-shop';
        }
        return null;
      }

      // User is logged in, is merchant, and shop is setup, prevent accessing onboarding/guest routes
      if (location == '/login' || location == '/register' || location == '/setup-shop') {
        return '/';
      }

      return null;
    },
  );
});

CustomTransitionPage<T> buildFadeThroughPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final scaleCurve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      final scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(scaleCurve);
      
      final fadeCurve = CurvedAnimation(parent: animation, curve: Curves.easeIn);
      final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(fadeCurve);

      return FadeTransition(
        opacity: fadeAnimation,
        child: ScaleTransition(
          scale: scaleAnimation,
          child: child,
        ),
      );
    },
  );
}

CustomTransitionPage<T> buildSlideRightPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 400),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slideCurve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
        reverseCurve: Curves.easeInQuint,
      );
      final slideAnimation = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(slideCurve);

      return SlideTransition(
        position: slideAnimation,
        child: child,
      );
    },
  );
}
