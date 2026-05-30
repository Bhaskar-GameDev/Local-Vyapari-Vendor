import 'package:flutter/material.dart';

import '../../core/exceptions/error_handler.dart';
import '../../core/theme/app_colors.dart';

/// A reusable full-area error state widget for use inside [AsyncValue.when]
/// error callbacks. Shows an icon, a user-friendly message from
/// [ErrorHandler.getMessage], and an optional retry button.
class ErrorView extends StatelessWidget {
  final Object error;

  /// Displayed as a bold title above the detail message. Optional.
  final String? title;

  /// When provided, renders a "Try Again" button that calls this callback.
  final VoidCallback? onRetry;

  const ErrorView({
    super.key,
    required this.error,
    this.title,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              ErrorHandler.getMessage(error),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
