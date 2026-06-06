// ignore_for_file: use_build_context_synchronously
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/feedback_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../common/error_dialog.dart';
import '../../common/custom_snack_bar.dart';
import '../../common/primary_button.dart';
import '../../common/responsive_center.dart';

/// Lets a signed-in vendor send feedback (bug / feature / general) to the shared
/// `feedback` collection consumed by the admin app.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();

  FeedbackType _type = FeedbackType.general;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Prefer the Firebase Auth email; fall back to the stored profile email so
    // phone-OTP vendors (whose auth email may be absent) still get tagged.
    final profileEmail =
        ref.read(userProfileProvider).value?['email']?.toString();
    final email = (user.email != null && user.email!.isNotEmpty)
        ? user.email!
        : (profileEmail ?? '');

    setState(() => _isSubmitting = true);
    try {
      await ref.read(feedbackServiceProvider).submitFeedback(
            userId: user.uid,
            userEmail: email,
            type: _type,
            message: _messageController.text,
          );
      if (!mounted) return;
      CustomSnackBar.showSuccess(
        context: context,
        title: l10n.feedbackSubmittedTitle,
        message: l10n.feedbackSubmittedBody,
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppErrorDialog.show(
        context: context,
        title: l10n.feedbackFailedTitle,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sendFeedback)),
      body: SafeArea(
        child: ResponsiveCenter(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.feedbackHeading,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  AppSpacing.verticalXs,
                  Text(
                    l10n.feedbackSubheading,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  AppSpacing.verticalLg,
                  Text(
                    l10n.feedbackTypeQuestion,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  AppSpacing.verticalSm,
                  _TypeSelector(
                    selected: _type,
                    onChanged:
                        _isSubmitting ? null : (t) => setState(() => _type = t),
                    l10n: l10n,
                  ),
                  AppSpacing.verticalLg,
                  Text(
                    l10n.feedbackMessageLabel,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  AppSpacing.verticalSm,
                  TextFormField(
                    controller: _messageController,
                    maxLines: 6,
                    maxLength: kFeedbackMaxLength,
                    textInputAction: TextInputAction.newline,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: l10n.feedbackMessageHint,
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return l10n.feedbackMessageRequired;
                      }
                      return null;
                    },
                  ),
                  AppSpacing.verticalMd,
                  PrimaryButton(
                    text: l10n.feedbackSubmit,
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented chips for choosing the feedback type.
class _TypeSelector extends StatelessWidget {
  const _TypeSelector({
    required this.selected,
    required this.onChanged,
    required this.l10n,
  });

  final FeedbackType selected;
  final ValueChanged<FeedbackType>? onChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final items = <(FeedbackType, String, IconData)>[
      (FeedbackType.bug, l10n.feedbackTypeBug, Icons.bug_report_outlined),
      (FeedbackType.feature, l10n.feedbackTypeFeature, Icons.lightbulb_outline),
      (
        FeedbackType.general,
        l10n.feedbackTypeGeneral,
        Icons.chat_bubble_outline
      ),
    ];

    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final (type, label, icon) in items)
          ChoiceChip(
            label: Text(label),
            avatar: Icon(
              icon,
              size: 18,
              color: selected == type ? Colors.white : AppColors.textSecondary,
            ),
            selected: selected == type,
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(
              color: selected == type ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            onSelected: onChanged == null ? null : (_) => onChanged!(type),
          ),
      ],
    );
  }
}
