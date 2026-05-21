import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../common/app_animations.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    
    final authState = ref.read(authStateProvider);
    
    authState.when(
      data: (user) {
        if (!mounted) return;
        context.go('/');
      },
      loading: () {
        Future.delayed(const Duration(milliseconds: 500), _navigate);
      },
      error: (_, __) {
        if (!mounted) return;
        context.go('/login');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FadeInSlide(
              duration: Duration(milliseconds: 800),
              slideOffset: 40.0,
              child: Icon(Icons.storefront_rounded, size: 80, color: Colors.white),
            ),
            const SizedBox(height: 16),
            FadeInSlide(
              duration: const Duration(milliseconds: 800),
              delay: const Duration(milliseconds: 200),
              slideOffset: 30.0,
              child: Text(
                'Local Vyapari',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeInSlide(
              duration: const Duration(milliseconds: 800),
              delay: const Duration(milliseconds: 450),
              slideOffset: 20.0,
              child: Text(
                'Vendor App',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 56),
            const FadeInSlide(
              duration: Duration(milliseconds: 800),
              delay: const Duration(milliseconds: 700),
              slideOffset: 10.0,
              child: CircularProgressIndicator(
                color: Colors.white54,
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

