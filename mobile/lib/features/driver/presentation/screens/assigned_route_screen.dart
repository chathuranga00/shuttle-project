import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/driver_assignment.dart';
import '../providers/driver_providers.dart';

/// Screen displaying the driver's currently assigned route and sequence of stops.
/// Spec Section 18: Simple, accessible layout with large stops timeline.
class AssignedRouteScreen extends ConsumerWidget {
  const AssignedRouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final assignmentAsync = ref.watch(driverAssignmentProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assigned Route'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(driverAssignmentProvider),
          ),
        ],
      ),
      body: assignmentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 56, color: Colors.red),
                const SizedBox(height: 16),
                Text('Could not load route details', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(err.toString(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(driverAssignmentProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (assignment) {
          final route = assignment.route;
          if (route == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.alt_route_rounded,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No Route Currently Assigned',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please contact the shuttle operations desk to assign a route to your schedule.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }

          final stops = route.stops;

          return Column(
            children: [
              // ── Route Overview Card ────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade400,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        route.code,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      route.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (route.description != null &&
                        route.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        route.description!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            color: Colors.white70, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          route.estimatedDurationMinutes != null
                              ? '~${route.estimatedDurationMinutes} mins estimated'
                              : 'Variable duration',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.place_outlined,
                            color: Colors.white70, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${stops.length} designated stops',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Stops Header ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'Stops in Sequence',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${stops.length} Total',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),

              // ── Timeline List of Stops ─────────────────────────────
              Expanded(
                child: stops.isEmpty
                    ? Center(
                        child: Text(
                          'No stops configured for this route',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        itemCount: stops.length,
                        itemBuilder: (context, index) {
                          final stop = stops[index];
                          final isFirst = index == 0;
                          final isLast = index == stops.length - 1;

                          return _StopTimelineTile(
                            stop: stop,
                            isFirst: isFirst,
                            isLast: isLast,
                            index: index,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StopTimelineTile extends StatelessWidget {
  const _StopTimelineTile({
    required this.stop,
    required this.isFirst,
    required this.isLast,
    required this.index,
  });

  final DriverRouteStop stop;
  final bool isFirst;
  final bool isLast;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = isFirst
        ? Colors.green.shade700
        : isLast
            ? Colors.red.shade700
            : theme.colorScheme.primary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Timeline connector & dot ───────────────────────────────
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst ? Colors.transparent : Colors.grey.shade300,
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: indicatorColor.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${stop.sequence > 0 ? stop.sequence : index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ── Stop Details Card ──────────────────────────────────────
          Expanded(
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            stop.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isFirst)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ORIGIN',
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          )
                        else if (isLast)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'TERMINUS',
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.qr_code_rounded,
                            size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Stop Code: ${stop.qrCode}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
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
