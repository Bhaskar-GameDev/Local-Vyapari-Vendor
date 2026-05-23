import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/custom_text_field.dart';
import '../../common/primary_button.dart';
import '../../common/app_animations.dart';
import '../../common/custom_snack_bar.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_dimensions.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).register(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          'merchant',
          null,
          phone: '+91${_phoneController.text.trim()}',
        );

    if (!mounted) return;

    if (!success) {
      final error = ref.read(authProvider).error;
      CustomSnackBar.showError(
        context: context,
        message: error ?? 'Registration failed',
        title: 'Registration Failed',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.horizontalPadding,
              vertical: AppSpacing.lg,
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: AppDimensions.maxFormWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSpacing.verticalSm,
                    FadeInSlide(
                      duration: const Duration(milliseconds: 500),
                      slideOffset: 20,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: AppRadius.borderMedium,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.storefront, color: AppColors.primary, size: 28),
                            AppSpacing.horizontalMd,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Join Local Vyapari',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  AppSpacing.verticalXs,
                                  Text(
                                    'Reach thousands of nearby customers',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AppSpacing.verticalXl,
                    
                    FadeInSlide(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 100),
                      slideOffset: 16,
                      child: CustomTextField(
                        label: 'Email Address',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Email is required';
                          if (!val.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                    ),
                    AppSpacing.verticalMd,

                    FadeInSlide(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 200),
                      slideOffset: 16,
                      child: CustomTextField(
                        label: 'Phone Number',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_android,
                        prefixText: '+91 ',
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Phone number is required';
                          if (val.length != 10) return 'Enter a valid 10-digit number';
                          return null;
                        },
                      ),
                    ),
                    AppSpacing.verticalMd,
                    
                    FadeInSlide(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 300),
                      slideOffset: 16,
                      child: CustomTextField(
                        label: 'Password',
                        controller: _passwordController,
                        obscureText: true,
                        prefixIcon: Icons.lock_outline,
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Password is required';
                          if (val.length < 6) return 'At least 6 characters required';
                          return null;
                        },
                      ),
                    ),
                    AppSpacing.verticalMd,
                    
                    FadeInSlide(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 400),
                      slideOffset: 16,
                      child: CustomTextField(
                        label: 'Confirm Password',
                        controller: _confirmPasswordController,
                        obscureText: true,
                        prefixIcon: Icons.lock_outline,
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Please confirm your password';
                          if (val != _passwordController.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                    ),
                    AppSpacing.verticalXl,
                    
                    FadeInSlide(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 500),
                      slideOffset: 16,
                      child: ScaleOnTap(
                        child: PrimaryButton(
                          text: 'Create My Store',
                          isLoading: authState.isLoading,
                          onPressed: _handleRegister,
                        ),
                      ),
                    ),
                    AppSpacing.verticalMd,
                    
                    FadeInSlide(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 600),
                      slideOffset: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account?',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Sign In'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
