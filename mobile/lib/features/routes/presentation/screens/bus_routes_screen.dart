import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../data/models/route_list_item.dart';
import '../providers/route_provider.dart';

class BusRoutesScreen extends ConsumerWidget {
  const BusRoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(routeListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Routes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(routeListProvider),
          ),
        ],
      ),
      body: routesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(routeListProvider),
        ),
        data: (routes) {
          if (routes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route_rounded,
                      size: 64,
                      color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text('No routes available',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Check back later.',
                      style: theme.textTheme.bodyMedium),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(routeListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: routes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) =>
                  _RouteCard(route: routes[index]),
            ),
          );
        },
      ),
    );
  }
}

// ── Route card ────────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.route});
  final RouteListItem route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = route.isActive;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(
          AppRoutes.busStops,
          extra: {'routeId': route.id, 'routeName': route.name},
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Route icon badge
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.directions_bus_rounded,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),

              // Route info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(route.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      route.code,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.55),
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    if (route.estimatedDurationMinutes != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 13,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Text(
                            '~${route.estimatedDurationMinutes} min',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Status + chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(isActive: isActive),
                  const SizedBox(height: 8),
                  Icon(Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? Colors.green.shade400 : Colors.grey.shade400,
          width: 0.8,
        ),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.signal_wifi_connected_no_internet_4_rounded,
                size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Could not load routes',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
