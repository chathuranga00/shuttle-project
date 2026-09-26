import 'package:flutter/material.dart';

/// Displays a user-friendly error message in a prominent banner.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, this.onDismiss});

  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
