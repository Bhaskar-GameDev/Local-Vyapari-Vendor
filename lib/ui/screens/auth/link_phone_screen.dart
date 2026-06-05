// ignore_for_file: use_build_context_synchronously
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../common/custom_text_field.dart';
import '../../common/primary_button.dart';
import '../../common/custom_snack_bar.dart';
import '../../common/error_dialog.dart';
import '../../common/resend_otp_timer.dart';
import '../../../l10n/app_localizations.dart';

/// Collects and verifies a mobile number for accounts that signed in without
/// one (Google / Apple). The marketplace keys identity and discovery on phone,
/// so the router parks the vendor here until a number is verified. On success
/// the OTP bind writes `users/{uid}.phone` + `verified:true`, the profile
/// stream emits, and the router redirect moves the vendor on to onboarding.
class LinkPhoneScreen extends ConsumerStatefulWidget {
  const LinkPhoneScreen({super.key});

  @override
  ConsumerState<LinkPhoneScreen> createState() => _LinkPhoneScreenState();
}

class _LinkPhoneScreenState extends ConsumerState<LinkPhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _otpSent = false;
  bool _isLoading = false;
  String? _verificationId;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String get _fullPhone => '+91${_phoneController.text.trim()}';

  Future<void> _sendOtp() async {
    final l10n = AppLocalizations.of(context);
    // Validate just the phone field (the OTP field may not exist yet).
    if (_phoneController.text.trim().length != 10) {
      AppErrorDialog.show(
        context: context,
        title: l10n.invalidNumber,
        message: l10n.enterValid10DigitNumberDot,
      );
      return;
    }

    setState(() => _isLoading = true);
    await ref.read(authProvider.notifier).requestBindPhoneOtp(
      _fullPhone,
      onCodeSent: (verificationId) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _otpSent = true;
          _verificationId = verificationId;
        });
        CustomSnackBar.showInfo(
          context: context,
          message: l10n.otpSentCheckSms,
          title: l10n.codeSent,
        );
      },
      onFailed: (error) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        AppErrorDialog.show(
          context: context,
          message: error,
          title: l10n.otpRequestFailed,
        );
      },
    );
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final verificationId = _verificationId;
    if (verificationId == null) return;
    final l10n = AppLocalizations.of(context);

    setState(() => _isLoading = true);
    final success = await ref
        .read(authProvider.notifier)
        .verifyBindPhoneAndSetPassword(
          verificationId,
          _otpController.text.trim(),
          _passwordController.text.trim(),
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      // The profile stream will emit the new phone and the router redirect
      // will move us on; show a confirmation in the meantime.
      CustomSnackBar.showSuccess(
        context: context,
        message: l10n.mobileNumberVerified,
        title: l10n.allSet,
      );
    } else {
      final error = ref.read(authProvider).error;
      AppErrorDialog.show(
        context: context,
        message: error ?? l10n.verificationFailedRetry,
        title: l10n.verificationFailed,
      );
    }
  }

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).logout();
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.addMobileNumber),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _signOut,
            child: Text(l10n.signOut),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.horizontalPadding,
              vertical: AppSpacing.lg,
            ),
            child: Container(
              constraints:
                  const BoxConstraints(maxWidth: AppDimensions.maxFormWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.phone_android_rounded,
                          color: AppColors.primary, size: 36),
                    ),
                    AppSpacing.verticalLg,
                    Text(
                      l10n.verifyYourMobileNumber,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                    ),
                    AppSpacing.verticalSm,
                    Text(
                      email != null
                          ? l10n.linkPhoneEmailContext(email)
                          : l10n.linkPhoneNoEmailContext,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    AppSpacing.verticalXl,
                    CustomTextField(
                      label: l10n.mobileNumber,
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_android,
                      prefixText: '+91 ',
                      readOnly: _otpSent,
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return l10n.phoneRequired;
                        }
                        if (val.length != 10) {
                          return l10n.enterValid10DigitNumber;
                        }
                        return null;
                      },
                    ),
                    if (_otpSent) ...[
                      AppSpacing.verticalMd,
                      CustomTextField(
                        label: l10n.enter6DigitOtp,
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.lock_outline,
                        validator: (val) {
                          if (val == null || val.isEmpty) return l10n.otpRequired;
                          if (val.length != 6) return l10n.otpMust6Digits;
                          return null;
                        },
                      ),
                      ResendOtpTimer(
                        enabled: !_isLoading,
                        onResend: _sendOtp,
                      ),
                      AppSpacing.verticalMd,
                      CustomTextField(
                        label: l10n.password,
                        controller: _passwordController,
                        obscureText: true,
                        prefixIcon: Icons.lock_person_outlined,
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return l10n.passwordRequired;
                          }
                          if (val.length < 6) return l10n.passwordMinChars;
                          return null;
                        },
                      ),
                      AppSpacing.verticalMd,
                      CustomTextField(
                        label: l10n.confirmPassword,
                        controller: _confirmPasswordController,
                        obscureText: true,
                        prefixIcon: Icons.lock_person_outlined,
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return l10n.pleaseConfirmPassword;
                          }
                          if (val != _passwordController.text) {
                            return l10n.passwordsDoNotMatch;
                          }
                          return null;
                        },
                      ),
                    ],
                    AppSpacing.verticalXl,
                    PrimaryButton(
                      text: _otpSent ? l10n.verifyAndContinue : l10n.sendOtp,
                      isLoading: _isLoading,
                      onPressed: _otpSent ? _verifyOtp : _sendOtp,
                    ),
                    if (_otpSent) ...[
                      AppSpacing.verticalSm,
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => setState(() {
                                  _otpSent = false;
                                  _otpController.clear();
                                  _verificationId = null;
                                }),
                        child: Text(l10n.changeNumber),
                      ),
                    ],
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
