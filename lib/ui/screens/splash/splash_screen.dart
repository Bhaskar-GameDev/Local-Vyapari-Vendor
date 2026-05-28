import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
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
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeInSlide(
              duration: const Duration(milliseconds: 800),
              slideOffset: 40.0,
              child: Image.asset(
                'assets/images/logo.webp',
                height: 180,
                fit: BoxFit.contain,
              ),
            ),
            AppSpacing.verticalMd,
            FadeInSlide(
              duration: const Duration(milliseconds: 800),
              delay: const Duration(milliseconds: 400),
              slideOffset: 20.0,
              child: Text(
                'Merchant Partner',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.0,
                  color: AppColors.primary.withOpacity(0.8),
                ),
              ),
            ),
            AppSpacing.verticalXl,
            FadeInSlide(
              duration: const Duration(milliseconds: 800),
              delay: const Duration(milliseconds: 700),
              slideOffset: 10.0,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
