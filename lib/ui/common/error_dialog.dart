import 'package:flutter/material.dart';

import '../../core/exceptions/error_handler.dart';
import '../../core/theme/app_colors.dart';

/// A single, app-wide error pop-up.
///
/// Use this instead of a snackbar for failures so the user must acknowledge
/// the problem. Two entry points:
///
///  * [show] when you already have a user-readable [message].
///  * [fromError] when you have a raw thrown object; it is run through
///    [ErrorHandler.getMessage] so the same mapping is used everywhere.
///
/// Both return a [Future] that completes when the dialog is dismissed, so
/// callers can `await` before navigating.
class AppErrorDialog {
  AppErrorDialog._();

  static Future<void> show({
    required BuildContext context,
    required String message,
    String title = 'Something went wrong',
    String buttonText = 'OK',
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => _ErrorDialogBody(
        title: title,
        message: message,
        buttonText: buttonText,
      ),
    );
  }

  /// Maps [error] to a readable string (and logs it in debug) before showing.
  static Future<void> fromError({
    required BuildContext context,
    required Object error,
    StackTrace? stackTrace,
    String title = 'Something went wrong',
    String buttonText = 'OK',
  }) {
    ErrorHandler.log(error, stackTrace);
    return show(
      context: context,
      message: ErrorHandler.getMessage(error),
      title: title,
      buttonText: buttonText,
    );
  }
}

class _ErrorDialogBody extends StatelessWidget {
  final String title;
  final String message;
  final String buttonText;

  const _ErrorDialogBody({
    required this.title,
    required this.message,
    required this.buttonText,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, color: AppColors.error, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
      ),
      actionsPadding: const EdgeInsets.only(right: 16, bottom: 12, left: 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          child: Text(
            buttonText,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
