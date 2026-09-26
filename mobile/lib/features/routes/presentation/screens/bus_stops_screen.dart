import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/route_stop_with_fare.dart';
import '../providers/route_provider.dart';

class BusStopsScreen extends ConsumerWidget {
  const BusStopsScreen({
    super.key,
    required this.routeId,
    required this.routeName,
  });

  final int    routeId;
  final String routeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stopsAsync = ref.watch(routeStopsProvider(routeId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(routeName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(routeStopsProvider(routeId)),
          ),
        ],
      ),
      body: stopsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          onRetry: () => ref.invalidate(routeStopsProvider(routeId)),
        ),
        data: (stops) {
          if (stops.isEmpty) {
            return Center(
              child: Text('No stops on this route.',
                  style: theme.textTheme.bodyLarge),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(routeStopsProvider(routeId)),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: stops.length,
              itemBuilder: (context, index) {
                final isLast = index == stops.length - 1;
                return _StopRow(
                  stop: stops[index],
                  isLast: isLast,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ── Stop row — stepper-style ───────────────────────────────────────────────────

class _StopRow extends StatelessWidget {
  const _StopRow({required this.stop, required this.isLast});

  final RouteStopWithFare stop;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const navy = Color(0xFF1A3A6B);
    const amber = Color(0xFFF5A623);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stepper column ──────────────────────────────────────────────
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Stop circle
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: navy,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: navy.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${stop.stopOrder}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                // Connector line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: navy.withValues(alpha: 0.2),
                      margin: const EdgeInsets.symmetric(vertical: 2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ── Stop detail card ────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 8 : 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stop name + status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            stop.stopName,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        if (stop.stopStatus != 'ACTIVE')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              stop.stopStatus,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),

                    // QR code label
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.qr_code_rounded,
                            size: 13,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.45)),
                        const SizedBox(width: 4),
                        Text(
                          stop.qrCode,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),

                    // Address
                    if (stop.address != null && stop.address!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 13,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.45)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              stop.address!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.45),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // ETA offset
                    if (stop.estimatedOffsetMinutes != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 13,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.45)),
                          const SizedBox(width: 4),
                          Text(
                            '~${stop.estimatedOffsetMinutes} min from start',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Fare — from API, never hard-coded
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: stop.hasFare
                            ? amber.withValues(alpha: 0.12)
                            : Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: stop.hasFare
                              ? amber.withValues(alpha: 0.4)
                              : Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.payments_rounded,
                            size: 15,
                            color: stop.hasFare
                                ? const Color(0xFFB47A0A)
                                : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            stop.hasFare
                                ? 'LKR ${stop.currentFare!.toStringAsFixed(2)}'
                                : 'Fare not configured',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: stop.hasFare
                                  ? const Color(0xFF7A5200)
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 56, color: Colors.grey),
          const SizedBox(height: 16),
          Text('Could not load stops',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
