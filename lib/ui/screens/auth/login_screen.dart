// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../core/security/social_auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../common/custom_text_field.dart';
import '../../common/primary_button.dart';
import '../../common/app_animations.dart';
import '../../common/error_dialog.dart';
import '../../../l10n/app_localizations.dart';
import 'reset_password_screen.dart';

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
  bool _isSocialLoading = false;

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

    // The router redirect handles navigation on success; a failure surfaces via
    // the authProvider error listener in build().
    if (_isEmailMode) {
      await ref.read(authProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );
    } else {
      await ref.read(authProvider.notifier).loginWithPhoneAndPassword(
            '+91${_phoneController.text.trim()}',
            _passwordController.text.trim(),
          );
    }
  }

  Future<void> _handleSocial(Future<UserCredential?> Function() signIn) async {
    // The Google/Apple flow runs outside the auth notifier, so authState.isLoading
    // never flips — without this local flag the screen sits idle (no feedback)
    // through the account picker and the blocking role-sync. The overlay covers
    // that gap.
    setState(() => _isSocialLoading = true);
    try {
      final credential = await signIn();
      if (credential == null) return; // user cancelled
      // The blocking beforeSignIn function syncs roles/claims; authStateChanges
      // + the router redirect take it from here.
    } catch (e, st) {
      if (mounted) {
        AppErrorDialog.fromError(
          context: context,
          error: e,
          stackTrace: st,
          title: AppLocalizations.of(context).signInFailed,
        );
      }
    } finally {
      // On success the router redirect disposes this screen (mounted == false),
      // so the overlay stays up until we navigate away; on cancel/error it clears.
      if (mounted) setState(() => _isSocialLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final l10n = AppLocalizations.of(context);
    final busy = authState.isLoading || _isSocialLoading;

    // Surface any sign-in failure as a pop-up the user must acknowledge.
    ref.listen<AuthNotifierState>(authProvider, (prev, next) {
      final err = next.error;
      if (err != null && err != prev?.error && mounted) {
        AppErrorDialog.show(
          context: context,
          message: err,
          title: l10n.authenticationFailed,
        );
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.horizontalPadding,
                  vertical: AppSpacing.lg,
                ),
                child: Container(
                  constraints: const BoxConstraints(
                      maxWidth: AppDimensions.maxFormWidth),
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
                                l10n.merchantPortal,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      letterSpacing: 1.2,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              AppSpacing.verticalXs,
                              Text(
                                l10n.storefrontTagline,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: AppRadius.borderMedium,
                              border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (!_isEmailMode) {
                                        setState(() => _isEmailMode = true);
                                        ref
                                            .read(authProvider.notifier)
                                            .clearError();
                                      }
                                    },
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: AppSpacing.sm),
                                      decoration: BoxDecoration(
                                        color: _isEmailMode
                                            ? AppColors.primary
                                            : Colors.transparent,
                                        borderRadius: AppRadius.borderSm,
                                      ),
                                      child: Text(
                                        l10n.emailAddress,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: _isEmailMode
                                              ? Colors.white
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
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
                                        ref
                                            .read(authProvider.notifier)
                                            .clearError();
                                      }
                                    },
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: AppSpacing.sm),
                                      decoration: BoxDecoration(
                                        color: !_isEmailMode
                                            ? AppColors.primary
                                            : Colors.transparent,
                                        borderRadius: AppRadius.borderSm,
                                      ),
                                      child: Text(
                                        l10n.phoneNumber,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: !_isEmailMode
                                              ? Colors.white
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
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
                                    label: l10n.emailAddress,
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    prefixIcon: Icons.email_outlined,
                                    validator: (val) {
                                      if (val == null || val.isEmpty) {
                                        return l10n.emailRequired;
                                      }
                                      if (!val.contains('@')) {
                                        return l10n.enterValidEmailAddress;
                                      }
                                      return null;
                                    },
                                  )
                                : CustomTextField(
                                    key: const ValueKey('phone_field'),
                                    label: l10n.phoneNumber,
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    prefixIcon: Icons.phone_android,
                                    prefixText: '+91 ',
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
                          ),
                        ),
                        AppSpacing.verticalMd,

                        FadeInSlide(
                          duration: const Duration(milliseconds: 600),
                          delay: const Duration(milliseconds: 500),
                          slideOffset: 20,
                          child: CustomTextField(
                            label: l10n.password,
                            controller: _passwordController,
                            obscureText: true,
                            prefixIcon: Icons.lock_outline,
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return l10n.passwordRequired;
                              }
                              if (val.length < 6) {
                                return l10n.passwordMinChars;
                              }
                              return null;
                            },
                          ),
                        ),

                        AppSpacing.verticalLg,

                        FadeInSlide(
                          duration: const Duration(milliseconds: 600),
                          delay: const Duration(milliseconds: 600),
                          slideOffset: 20,
                          child: ScaleOnTap(
                            child: PrimaryButton(
                              text: authState.isLoading
                                  ? l10n.signingIn
                                  : l10n.signIn,
                              isLoading: authState.isLoading,
                              onPressed: _handleLogin,
                            ),
                          ),
                        ),

                        AppSpacing.verticalLg,

                        // ── Social sign-in ──
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm),
                              child: Text(l10n.orContinueWith,
                                  style: Theme.of(context).textTheme.bodySmall),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        AppSpacing.verticalMd,
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () => _handleSocial(ref
                                  .read(socialAuthServiceProvider)
                                  .signInWithGoogle),
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: Text(l10n.continueWithGoogle),
                        ),
                        if (Platform.isIOS || Platform.isMacOS) ...[
                          AppSpacing.verticalSm,
                          OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () => _handleSocial(ref
                                    .read(socialAuthServiceProvider)
                                    .signInWithApple),
                            icon: const Icon(Icons.apple, size: 24),
                            label: Text(l10n.continueWithApple),
                          ),
                        ],

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
                                  final resetSuccess =
                                      await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ResetPasswordScreen(),
                                    ),
                                  );
                                  if (resetSuccess == true && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            l10n.passwordResetSuccess),
                                        backgroundColor: AppColors.success,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                                child: Text(l10n.forgotPassword),
                              ),
                              TextButton(
                                onPressed: () => context.push('/register'),
                                child: Text(l10n.createAccount),
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
          if (_isSocialLoading)
            const Positioned.fill(child: _SocialLoadingOverlay()),
        ],
      ),
    );
  }
}

/// Full-screen translucent barrier shown while a social (Google/Apple) sign-in
/// is in flight, so the screen isn't silently idle during the picker + role sync.
class _SocialLoadingOverlay extends StatelessWidget {
  const _SocialLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppLocalizations.of(context).signingYouIn,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
