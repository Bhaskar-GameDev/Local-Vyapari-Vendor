// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/custom_text_field.dart';
import '../../common/primary_button.dart';
import '../../common/app_animations.dart';
import '../../common/custom_snack_bar.dart';
import '../../common/error_dialog.dart';
import '../../common/resend_otp_timer.dart';
import '../../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);

    // Show request loading dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(l10n.requestingVerification),
          ],
        ),
      ),
    );

    await authNotifier.sendRegistrationOtp(
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
            // Mutable so a resend can swap in the fresh verificationId.
            String currentVerificationId = verificationId;

            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: Text(l10n.verifyPhoneNumber),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.otpSentToPhone(phone)),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: l10n.sixDigitOtp,
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.lock_outline,
                      ),
                      ResendOtpTimer(
                        enabled: !isVerifying,
                        onResend: () {
                          authNotifier.sendRegistrationOtp(
                            phone,
                            onCodeSent: (vid) {
                              currentVerificationId = vid;
                              if (context.mounted) {
                                CustomSnackBar.showSuccess(
                                  context: context,
                                  message: l10n.newOtpSent,
                                  title: l10n.codeResent,
                                );
                              }
                            },
                            onFailed: (err) {
                              if (context.mounted) {
                                AppErrorDialog.show(
                                  context: context,
                                  message: err,
                                  title: l10n.resendFailed,
                                );
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: isVerifying ? null : () => Navigator.pop(dialogContext, false),
                      child: Text(l10n.commonCancel),
                    ),
                    ElevatedButton(
                      onPressed: isVerifying ? null : () async {
                        final code = codeController.text.trim();
                        if (code.length != 6) return;

                        setState(() => isVerifying = true);

                        final regSuccess = await authNotifier.registerWithPhoneOtp(
                          verificationId: currentVerificationId,
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
                          : Text(l10n.verifyAndRegister),
                    ),
                  ],
                );
              },
            );
          },
        ).then((verified) {
          if (!context.mounted) return;
          if (verified != true) {
            final error = ref.read(authProvider).error;
            AppErrorDialog.show(
              context: context,
              message: error ?? l10n.verificationCanceledOrFailed,
              title: l10n.verificationFailed,
            );
          }
        });
      },
      onFailed: (error) {
        // Dismiss requesting dialog
        Navigator.pop(context);

        AppErrorDialog.show(
          context: context,
          message: error,
          title: l10n.otpRequestFailed,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createAccount),
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
                                    l10n.joinLocalVyapari,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  AppSpacing.verticalXs,
                                  Text(
                                    l10n.reachNearbyCustomers,
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
                        label: l10n.emailAddress,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        validator: (val) {
                          if (val == null || val.isEmpty) return l10n.emailRequired;
                          if (!val.contains('@')) return l10n.enterValidEmail;
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
                        label: l10n.phoneNumber,
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_android,
                        prefixText: '+91 ',
                        validator: (val) {
                          if (val == null || val.isEmpty) return l10n.phoneRequired;
                          if (val.length != 10) return l10n.enterValid10DigitNumber;
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
                        label: l10n.password,
                        controller: _passwordController,
                        obscureText: true,
                        prefixIcon: Icons.lock_outline,
                        validator: (val) {
                          if (val == null || val.isEmpty) return l10n.passwordRequired;
                          if (val.length < 6) return l10n.atLeast6Chars;
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
                        label: l10n.confirmPassword,
                        controller: _confirmPasswordController,
                        obscureText: true,
                        prefixIcon: Icons.lock_outline,
                        validator: (val) {
                          if (val == null || val.isEmpty) return l10n.pleaseConfirmPassword;
                          if (val != _passwordController.text) return l10n.passwordsDoNotMatch;
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
                          text: l10n.createMyStore,
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
                            l10n.alreadyHaveAccount,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(l10n.signIn),
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
