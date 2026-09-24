import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/boarding_history_item.dart';
import '../providers/boarding_provider.dart';

/// Full travel history screen — lists all boarding records, most recent first.
class TravelHistoryScreen extends ConsumerWidget {
  const TravelHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(boardingHistoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(boardingHistoryProvider),
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
              Text('Could not load history',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => ref.invalidate(boardingHistoryProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded,
                      size: 64,
                      color: theme.colorScheme.primary.withValues(alpha: 0.25)),
                  const SizedBox(height: 16),
                  Text('No journeys yet', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Your boarding records will appear here.',
                      style: theme.textTheme.bodyMedium),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(boardingHistoryProvider),
            child: ListView.separated(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) =>
                  _HistoryCard(item: items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});
  final BoardingHistoryItem item;

  static final _dateFmt = DateFormat('d MMM yyyy  HH:mm');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPaid = item.isPaid;

    DateTime? boardedAt;
    try {
      boardedAt = DateTime.parse(item.boardedAt).toLocal();
    } catch (_) {}

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // ── Icon badge ────────────────────────────────────────────
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.directions_bus_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),

            // ── Details ───────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.routeName,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    item.busStopName,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  if (boardedAt != null)
                    Text(
                      _dateFmt.format(boardedAt),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            ),

            // ── Fare + status ─────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.fareAmount != null
                      ? 'LKR ${item.fareAmount!.toStringAsFixed(2)}'
                      : '—',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPaid
                          ? Colors.green.shade400
                          : Colors.orange.shade400,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    item.paymentStatus,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isPaid
                          ? Colors.green.shade700
                          : Colors.orange.shade800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
