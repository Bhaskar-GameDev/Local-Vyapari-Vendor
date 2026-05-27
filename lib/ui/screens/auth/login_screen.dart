import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/custom_text_field.dart';
import '../../common/primary_button.dart';
import '../../common/app_animations.dart';
import '../../common/custom_snack_bar.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_dimensions.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isEmailMode = true;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_clearErrorIfNeeded);
    _phoneController.addListener(_clearErrorIfNeeded);
    _passwordController.addListener(_clearErrorIfNeeded);
  }

  void _clearErrorIfNeeded() {
    if (ref.read(authProvider).error != null) {
      ref.read(authProvider.notifier).clearError();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    _isEmailMode
        ? await ref.read(authProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          )
        : await ref.read(authProvider.notifier).loginWithPhoneAndPassword(
            '+91${_phoneController.text.trim()}',
            _passwordController.text.trim(),
          );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
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
                    AppSpacing.verticalXl,
                    FadeInSlide(
                      duration: const Duration(milliseconds: 600),
                      slideOffset: 30,
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ),
                    AppSpacing.verticalSm,
                    FadeInSlide(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 100),
                      slideOffset: 20,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Merchant Portal',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              letterSpacing: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          AppSpacing.verticalXs,
                          Text(
                            'Local Vyapari Storefront Terminal',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.verticalXxl,

                    // Toggle tabs
                    FadeInSlide(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 300),
                      slideOffset: 20,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: AppRadius.borderMedium,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                             Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (!_isEmailMode) {
                                    setState(() => _isEmailMode = true);
                                    ref.read(authProvider.notifier).clearError();
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: _isEmailMode ? AppColors.primary : Colors.transparent,
                                    borderRadius: AppRadius.borderSm,
                                  ),
                                  child: Text(
                                    'Email Address',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _isEmailMode ? Colors.white : AppColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (_isEmailMode) {
                                    setState(() => _isEmailMode = false);
                                    ref.read(authProvider.notifier).clearError();
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: !_isEmailMode ? AppColors.primary : Colors.transparent,
                                    borderRadius: AppRadius.borderSm,
                                  ),
                                  child: Text(
                                    'Phone Number',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: !_isEmailMode ? Colors.white : AppColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AppSpacing.verticalXl,

                    // Fields based on selection (AnimatedSwitcher to transition between fields!)
                    FadeInSlide(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 400),
                      slideOffset: 20,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _isEmailMode
                            ? CustomTextField(
                                key: const ValueKey('email_field'),
                                label: 'Email Address',
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: Icons.email_outlined,
                                validator: (val) {
                                  if (val == null || val.isEmpty) return 'Email is required';
                                  if (!val.contains('@')) return 'Enter a valid email address';
                                  return null;
                                },
                              )
                            : CustomTextField(
                                key: const ValueKey('phone_field'),
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
                    ),
                    AppSpacing.verticalMd,
                    
                    FadeInSlide(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 500),
                      slideOffset: 20,
                      child: CustomTextField(
                        label: 'Password',
                        controller: _passwordController,
                        obscureText: true,
                        prefixIcon: Icons.lock_outline,
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Password is required';
                          if (val.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),
                    ),

                    if (authState.error != null) ...[
                      AppSpacing.verticalMd,
                      FadeInSlide(
                        duration: const Duration(milliseconds: 350),
                        slideOffset: 12,
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.06),
                            borderRadius: AppRadius.borderLg,
                            border: Border.all(
                              color: AppColors.error.withOpacity(0.25),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.error,
                                size: 24,
                              ),
                              AppSpacing.horizontalSm,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Authentication Failure',
                                      style: TextStyle(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    AppSpacing.verticalXs,
                                    Text(
                                      authState.error!,
                                      style: TextStyle(
                                        color: AppColors.error.withOpacity(0.85),
                                        fontSize: 13,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    AppSpacing.verticalLg,
                    
                    FadeInSlide(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 600),
                      slideOffset: 20,
                      child: ScaleOnTap(
                        child: PrimaryButton(
                          text: authState.isLoading ? 'Signing In...' : 'Sign In',
                          isLoading: authState.isLoading,
                          onPressed: _handleLogin,
                        ),
                      ),
                    ),

                    AppSpacing.verticalMd,
                    
                    FadeInSlide(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 700),
                      slideOffset: 20,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () async {
                              final resetSuccess = await showDialog<bool>(
                                context: context,
                                builder: (_) => _ResetPasswordDialog(ref: ref),
                              );
                              if (resetSuccess == true && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Password reset successfully! You can now log in.'),
                                    backgroundColor: AppColors.success,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            child: const Text('Forgot Password?'),
                          ),
                          TextButton(
                            onPressed: () => context.push('/register'),
                            child: const Text('Create Account'),
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

class _ResetPasswordDialog extends StatefulWidget {
  final WidgetRef ref;

  const _ResetPasswordDialog({required this.ref});

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _otpSent = false;
  bool _isLoading = false;
  String? _verificationId;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Invalid Number'),
          content: const Text('Please enter a valid 10-digit number'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final fullPhone = '+91$phone';
    await widget.ref.read(authProvider.notifier).requestPasswordResetOtp(
      fullPhone,
      onCodeSent: (verificationId) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _otpSent = true;
            _verificationId = verificationId;
          });
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('OTP Sent'),
              content: const Text('OTP sent successfully. Please check your messages.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      },
      onFailed: (error) {
        if (mounted) {
          setState(() => _isLoading = false);
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Error'),
              content: Text(error),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  void _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final code = _otpController.text.trim();
    final newPassword = _passwordController.text.trim();

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Resetting password..."),
            ],
          ),
        );
      },
    );

    final success = await widget.ref.read(authProvider.notifier).resetPasswordWithPhoneOtp(
      verificationId: _verificationId!,
      code: code,
      newPassword: newPassword,
    );

    if (mounted) {
      Navigator.pop(context); // Dismiss progress dialog
      
      if (success) {
        Navigator.pop(context, true); // Close reset dialog, return true
      } else {
        final error = widget.ref.read(authProvider).error;
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.error),
                SizedBox(width: 8),
                Text('Error'),
              ],
            ),
            content: Text(error ?? 'Password reset failed'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Password via OTP'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              CustomTextField(
                label: 'Registered Phone Number',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_android,
                prefixText: '+91 ',
                readOnly: _otpSent,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Phone number is required';
                  if (val.length != 10) return 'Enter a valid 10-digit number';
                  return null;
                },
              ),
              if (_otpSent) ...[
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Enter 6-Digit OTP',
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.lock_outline,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'OTP is required';
                    if (val.length != 6) return 'OTP must be 6 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'New Password',
                  controller: _passwordController,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'New password is required';
                    if (val.length < 6) return 'At least 6 characters required';
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : (_otpSent ? _resetPassword : _sendOtp),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_otpSent ? 'Reset Password' : 'Send OTP'),
        ),
      ],
    );
  }
}
