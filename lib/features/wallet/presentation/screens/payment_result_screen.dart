import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';

/// Shows the outcome after returning from the payment gateway.
class PaymentResultScreen extends StatelessWidget {
  const PaymentResultScreen({
    super.key,
    required this.success,
    required this.amount,
  });

  final bool   success;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor:
                    success ? Colors.green : Colors.orange,
                child: Icon(
                  success
                      ? Icons.check_rounded
                      : Icons.hourglass_top_rounded,
                  color: Colors.white,
                  size: 56,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                success ? 'Payment Successful!' : 'Payment Pending',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: success ? Colors.green.shade700 : Colors.orange.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                success
                    ? 'LKR ${amount.toStringAsFixed(2)} has been added\nto your wallet.'
                    : 'We could not confirm your payment yet.\n'
                        'Your wallet will be updated once the payment\n'
                        'is verified. Check back in a few minutes.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: () => context.go(AppRoutes.wallet),
                child: const Text('View Wallet'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.studentDashboard),
                child: const Text('Back to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
