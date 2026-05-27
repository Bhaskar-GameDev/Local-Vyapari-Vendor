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

    final email = _emailController.text.trim();
    final phone = '+91${_phoneController.text.trim()}';
    final password = _passwordController.text.trim();
    final authNotifier = ref.read(authProvider.notifier);

    // Show request loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Requesting verification..."),
          ],
        ),
      ),
    );

    final success = await authNotifier.sendRegistrationOtp(
      phone,
      onCodeSent: (verificationId) {
        // Dismiss requesting dialog
        Navigator.pop(context);

        // Show OTP verification dialog
        showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            final codeController = TextEditingController();
            bool isVerifying = false;

            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text('Verify Phone Number'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('We have sent a verification OTP to $phone.'),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: '6-Digit OTP',
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.lock_outline,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: isVerifying ? null : () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: isVerifying ? null : () async {
                        final code = codeController.text.trim();
                        if (code.length != 6) return;

                        setState(() => isVerifying = true);

                        final regSuccess = await authNotifier.registerWithPhoneOtp(
                          verificationId: verificationId,
                          code: code,
                          email: email,
                          password: password,
                          role: 'merchant',
                          phone: phone,
                        );

                        if (context.mounted) {
                          setState(() => isVerifying = false);
                          Navigator.pop(dialogContext, regSuccess);
                        }
                      },
                      child: isVerifying
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Verify & Register'),
                    ),
                  ],
                );
              },
            );
          },
        ).then((verified) {
          if (verified != true) {
            final error = ref.read(authProvider).error;
            CustomSnackBar.showError(
              context: context,
              message: error ?? 'Verification canceled or failed',
              title: 'Verification Failed',
            );
          }
        });
      },
      onFailed: (error) {
        // Dismiss requesting dialog
        Navigator.pop(context);

        CustomSnackBar.showError(
          context: context,
          message: error,
          title: 'OTP Request Failed',
        );
      },
    );
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
