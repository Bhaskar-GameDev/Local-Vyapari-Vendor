import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../common/app_animations.dart';
import '../../common/custom_text_field.dart';
import '../../common/error_dialog.dart';
import '../../common/primary_button.dart';
import '../../common/resend_otp_timer.dart';
import '../../../l10n/app_localizations.dart';

/// Full-screen, two-step password reset.
///
/// Step 1 verifies the registered phone number and sends an OTP; step 2 takes
/// the OTP plus a new password. Pops with `true` once the password is reset, so
/// the caller can show a confirmation. The actual auth work lives in
/// [AuthNotifier.requestPasswordResetOtp] / [AuthNotifier.resetPasswordWithPhoneOtp]
/// — this screen is purely the UI.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _verifyFormKey = GlobalKey<FormState>();
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
    // In step 1 validate the phone form; when resending from step 2 the number
    // is already locked in, so skip straight to the request.
    if (!_otpSent && !_phoneFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final fullPhone = '+91${_phoneController.text.trim()}';
    final l10n = AppLocalizations.of(context);

    await ref.read(authProvider.notifier).requestPasswordResetOtp(
      fullPhone,
      onCodeSent: (verificationId) {
        if (!mounted) return;
        final firstSend = !_otpSent;
        setState(() {
          _isLoading = false;
          _otpSent = true;
          _verificationId = verificationId;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(firstSend
                ? l10n.otpSentToShort(fullPhone)
                : l10n.newOtpSentShort),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
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

  void _resetPassword() async {
    if (!_verifyFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final success =
        await ref.read(authProvider.notifier).resetPasswordWithPhoneOtp(
              verificationId: _verificationId!,
              code: _otpController.text.trim(),
              newPassword: _passwordController.text.trim(),
            );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.pop(context, true);
    } else {
      final l10n = AppLocalizations.of(context);
      AppErrorDialog.show(
        context: context,
        message: ref.read(authProvider).error ?? l10n.passwordResetFailed,
        title: l10n.passwordResetFailedTitle,
      );
    }
  }

  /// Return from step 2 to step 1 to correct the phone number.
  void _editNumber() {
    setState(() {
      _otpSent = false;
      _otpController.clear();
      _passwordController.clear();
      _verificationId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.resetPassword),
        // Block accidental back-navigation mid-request.
        automaticallyImplyLeading: !_isLoading,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.horizontalPadding,
              vertical: AppSpacing.lg,
            ),
            child: Container(
              constraints:
                  const BoxConstraints(maxWidth: AppDimensions.maxFormWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 90,
                    fit: BoxFit.contain,
                  ),
                  AppSpacing.verticalLg,
                  Text(
                    _otpSent ? l10n.enterTheCode : l10n.verifyYourNumber,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  AppSpacing.verticalXs,
                  Text(
                    _otpSent
                        ? l10n.resetCodeSentTo(_phoneController.text.trim())
                        : l10n.resetPhonePrompt,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  AppSpacing.verticalLg,
                  _StepBadge(otpSent: _otpSent),
                  AppSpacing.verticalLg,
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        sizeFactor: animation,
                        axisAlignment: -1,
                        child: child,
                      ),
                    ),
                    child: _otpSent ? _buildVerifyStep() : _buildPhoneStep(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _phoneFormKey,
      child: Column(
        key: const ValueKey('phone_step'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomTextField(
            label: l10n.registeredPhoneNumber,
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
          AppSpacing.verticalLg,
          ScaleOnTap(
            child: PrimaryButton(
              text: l10n.sendOtp,
              isLoading: _isLoading,
              onPressed: _sendOtp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyStep() {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _verifyFormKey,
      child: Column(
        key: const ValueKey('verify_step'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomTextField(
            label: l10n.enter6DigitOtp,
            controller: _otpController,
            keyboardType: TextInputType.number,
            prefixIcon: Icons.sms_outlined,
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
          AppSpacing.verticalSm,
          CustomTextField(
            label: l10n.newPasswordLabel,
            controller: _passwordController,
            obscureText: true,
            prefixIcon: Icons.lock_outline,
            validator: (val) {
              if (val == null || val.isEmpty) return l10n.newPasswordRequired;
              if (val.length < 6) return l10n.atLeast6Chars;
              return null;
            },
          ),
          AppSpacing.verticalLg,
          ScaleOnTap(
            child: PrimaryButton(
              text: l10n.resetPassword,
              isLoading: _isLoading,
              onPressed: _resetPassword,
            ),
          ),
          AppSpacing.verticalSm,
          TextButton.icon(
            onPressed: _isLoading ? null : _editNumber,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: Text(l10n.changePhoneNumber),
          ),
        ],
      ),
    );
  }
}

/// "Step N of 2" pill with a two-segment progress bar.
class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.otpSent});

  final bool otpSent;

  @override
  Widget build(BuildContext context) {
    Widget segment(bool active) => Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 4,
            decoration: BoxDecoration(
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: AppRadius.borderXs,
            ),
          ),
        );

    return Column(
      children: [
        Text(
          AppLocalizations.of(context).stepNOf2(otpSent ? 2 : 1),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        AppSpacing.verticalSm,
        Row(
          children: [
            segment(true),
            const SizedBox(width: 6),
            segment(otpSent),
          ],
        ),
      ],
    );
  }
}
