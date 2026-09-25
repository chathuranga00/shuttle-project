import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/wallet_provider.dart';

class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  static final _dateFmt = DateFormat('d MMM yyyy  HH:mm');

  static Color _statusColor(String status) => switch (status) {
        'SUCCESS'   => Colors.green.shade700,
        'PENDING'   => Colors.orange.shade700,
        'FAILED'    => Colors.red.shade700,
        'CANCELLED' => Colors.grey.shade600,
        _           => Colors.grey.shade600,
      };

  static IconData _statusIcon(String status) => switch (status) {
        'SUCCESS'   => Icons.check_circle_rounded,
        'PENDING'   => Icons.hourglass_top_rounded,
        'FAILED'    => Icons.cancel_rounded,
        'CANCELLED' => Icons.block_rounded,
        _           => Icons.help_outline_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(paymentHistoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(paymentHistoryProvider),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('Could not load payments',
                  style: theme.textTheme.titleMedium),
              TextButton.icon(
                onPressed: () => ref.invalidate(paymentHistoryProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text('No payment records yet.',
                  style: TextStyle(color: Colors.grey)),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(paymentHistoryProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final p = items[i];
                DateTime? dt;
                try {
                  dt = DateTime.parse(p.createdAt).toLocal();
                } catch (_) {}

                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor:
                          _statusColor(p.status).withValues(alpha: 0.12),
                      child: Icon(_statusIcon(p.status),
                          color: _statusColor(p.status), size: 20),
                    ),
                    title: Text(
                      p.description ?? p.type.replaceAll('_', ' '),
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (dt != null)
                          Text(_dateFmt.format(dt),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              )),
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor(p.status)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _statusColor(p.status)
                                  .withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            p.status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _statusColor(p.status),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      'LKR ${p.amount.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A3A6B),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
