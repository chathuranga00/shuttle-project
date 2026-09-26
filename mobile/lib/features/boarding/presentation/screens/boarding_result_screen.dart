import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../data/models/boarding_confirm_response.dart';

/// Shows the final outcome of a boarding attempt.
/// [result] is either a [BoardingConfirmResponse] (success) or a [String] (error msg).
///
/// A boarding is ONLY shown as success here — never before the server confirms.
class BoardingResultScreen extends StatelessWidget {
  const BoardingResultScreen({super.key, required this.result});

  /// Either a [BoardingConfirmResponse] (success) or a [String] (error message).
  final Object result;

  @override
  Widget build(BuildContext context) {
    if (result is BoardingConfirmResponse) {
      return _SuccessView(response: result as BoardingConfirmResponse);
    }
    return _ErrorView(message: result as String);
  }
}

// ── Success ───────────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.response});
  final BoardingConfirmResponse response;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = response;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Big tick ────────────────────────────────────────────
              const CircleAvatar(
                radius: 52,
                backgroundColor: Colors.green,
                child: Icon(Icons.check_rounded,
                    color: Colors.white, size: 56),
              ),
              const SizedBox(height: 24),

              Text(
                r.alreadyBoarded ? 'Already Boarded' : 'Boarding Confirmed!',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                r.alreadyBoarded
                    ? 'This trip was already recorded for you.'
                    : 'Your boarding has been recorded.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),

              // ── Detail card ─────────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Row(label: 'Stop',    value: r.stopName),
                      _Row(label: 'Route',   value: r.routeName),
                      _Row(
                        label: 'Fare',
                        value: r.fareAmount != null
                            ? 'LKR ${r.fareAmount!.toStringAsFixed(2)}'
                            : 'Not set',
                      ),
                      const Divider(height: 20),
                      _StatusRow(status: r.paymentStatus),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Done button ─────────────────────────────────────────
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.studentDashboard),
                child: const Text('Done'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.push(AppRoutes.travelHistory),
                child: const Text('View Travel History'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  // Extract a clean message from exception toString if needed
  String get _cleanMessage {
    const prefix = 'ApiException(';
    if (message.contains(prefix)) {
      final start = message.lastIndexOf(': ') + 2;
      if (start > 1 && start < message.length) return message.substring(start);
    }
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: Colors.red.shade600,
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 56),
              ),
              const SizedBox(height: 24),

              Text(
                'Boarding Failed',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _cleanMessage,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.red.shade800),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton.icon(
                onPressed: () => context.go(AppRoutes.qrScanner),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan Again'),
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

// ── Shared row widgets ────────────────────────────────────────────────────────

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
            child: Text(label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final isPaid = status == 'PAID';
    return Row(
      children: [
        Text('Payment',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey.shade600)),
        const SizedBox(width: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isPaid
                ? Colors.green.withValues(alpha: 0.12)
                : Colors.orange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPaid ? Colors.green.shade400 : Colors.orange.shade400,
            ),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: isPaid
                  ? Colors.green.shade700
                  : Colors.orange.shade800,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}
