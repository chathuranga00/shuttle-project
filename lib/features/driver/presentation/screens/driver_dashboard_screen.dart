import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/driver_trip.dart';
import '../providers/driver_providers.dart';

/// Driver Dashboard per Spec Section 18:
/// Large buttons, high contrast, simple UI.
/// Displays:
/// - Assigned bus, route, and trip status.
/// - Passenger count and monthly / pay-per-trip split.
/// - VIEW TRIP, START TRIP, and END TRIP primary actions.
/// - Quick large navigation buttons to all driver sub-features.
class DriverDashboardScreen extends ConsumerStatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  ConsumerState<DriverDashboardScreen> createState() =>
      _DriverDashboardScreenState();
}

class _DriverDashboardScreenState
    extends ConsumerState<DriverDashboardScreen> {
  bool _isActionLoading = false;

  Future<void> _handleStartTrip(DriverTrip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Trip?'),
        content: Text(
          'Start scheduled trip for "${trip.routeName}" with Bus ${trip.busNumber}?\n\n'
          'Students will be able to board and validate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start Trip'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isActionLoading = true);
    final success = await ref
        .read(driverActionControllerProvider.notifier)
        .startTrip(trip.id);
    if (!mounted) return;
    setState(() => _isActionLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip started! Boarding is now active.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start trip. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleEndTrip(DriverTrip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Trip?'),
        content: Text(
          'Are you sure you want to end the trip for "${trip.routeName}"?\n\n'
          'Once ended, no further boardings can be recorded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, End Trip'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isActionLoading = true);
    final success = await ref
        .read(driverActionControllerProvider.notifier)
        .endTrip(trip.id);
    if (!mounted) return;
    setState(() => _isActionLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip ended and completed.'),
          backgroundColor: Colors.blueGrey,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to end trip. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tripAsync = ref.watch(currentTripProvider);
    final assignmentAsync = ref.watch(driverAssignmentProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(currentTripProvider);
              ref.invalidate(driverAssignmentProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(currentTripProvider);
            ref.invalidate(driverAssignmentProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Driver Identity Card ───────────────────────────
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor:
                              theme.colorScheme.primary.withValues(alpha: 0.1),
                          child: Icon(
                            Icons.drive_eta_rounded,
                            size: 32,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                assignmentAsync.maybeWhen(
                                  data: (a) => a.driverName.isNotEmpty
                                      ? a.driverName
                                      : 'Driver',
                                  orElse: () => 'Driver',
                                ),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'ON DUTY',
                                      style: TextStyle(
                                        color: Colors.green.shade900,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  assignmentAsync.maybeWhen(
                                    data: (a) => a.bus != null
                                        ? Text(
                                            'Bus ${a.bus!.busNumber}',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                    orElse: () => const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Today's Trip Section Header ────────────────────
                Text(
                  "Today's Assigned Trip",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Primary Trip Hero Card ─────────────────────────
                tripAsync.when(
                  loading: () => const Card(
                    child: SizedBox(
                      height: 160,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (err, _) => Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              color: Colors.red.shade800),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Could not load today\'s trip. Tap refresh to retry.',
                              style: TextStyle(color: Colors.red.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (trip) {
                    if (trip == null) {
                      return _NoTripTodayCard(assignmentAsync: assignmentAsync);
                    }
                    return _ActiveTripHeroCard(
                      trip: trip,
                      isActionLoading: _isActionLoading,
                      onStartTrip: () => _handleStartTrip(trip),
                      onEndTrip: () => _handleEndTrip(trip),
                    );
                  },
                ),
                const SizedBox(height: 28),

                // ── Fast Action Grid (Spec Section 18) ──────────────
                Text(
                  'Driver Controls & Services',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 14),

                _DriverNavCard(
                  icon: Icons.directions_bus_rounded,
                  title: 'Current Trip & Live Boardings',
                  subtitle: 'Real-time boarding feed and controls',
                  color: theme.colorScheme.primary,
                  onTap: () => context.push(AppRoutes.driverCurrentTrip),
                ),
                _DriverNavCard(
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'Scan Student Card',
                  subtitle: 'Verify virtual bus card and monthly pass',
                  color: Colors.teal.shade700,
                  onTap: () => context.push(AppRoutes.driverScanCard),
                ),
                _DriverNavCard(
                  icon: Icons.alt_route_rounded,
                  title: 'Assigned Route',
                  subtitle: 'View sequence of stops and estimated time',
                  color: Colors.indigo.shade700,
                  onTap: () => context.push(AppRoutes.driverAssignedRoute),
                ),
                _DriverNavCard(
                  icon: Icons.directions_bus_filled_outlined,
                  title: 'Assigned Bus Details',
                  subtitle: 'Capacity, registration plate, and specs',
                  color: Colors.blueGrey.shade800,
                  onTap: () => context.push(AppRoutes.driverAssignedBus),
                ),
                _DriverNavCard(
                  icon: Icons.emergency_share_rounded,
                  title: 'Emergency Report',
                  subtitle: 'Report accident, breakdown, or delay immediately',
                  color: Colors.red.shade700,
                  onTap: () => context.push(AppRoutes.driverEmergency),
                ),
                _DriverNavCard(
                  icon: Icons.history_rounded,
                  title: 'Trip History',
                  subtitle: 'View completed trips and passenger records',
                  color: Colors.deepPurple.shade700,
                  onTap: () => context.push(AppRoutes.driverTripHistory),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveTripHeroCard extends ConsumerWidget {
  const _ActiveTripHeroCard({
    required this.trip,
    required this.isActionLoading,
    required this.onStartTrip,
    required this.onEndTrip,
  });

  final DriverTrip trip;
  final bool isActionLoading;
  final VoidCallback onStartTrip;
  final VoidCallback onEndTrip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summaryAsync =
        trip.isActive ? ref.watch(liveTripSummaryProvider(trip.id)) : null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: trip.isActive ? Colors.green.shade300 : Colors.grey.shade200,
          width: trip.isActive ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Route & Status row ──────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    trip.routeName,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StatusBadge(status: trip.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Bus ${trip.busNumber}',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // ── Live Passenger Metrics (Active Trips) ────────────────
            if (trip.isActive && summaryAsync != null)
              summaryAsync.when(
                loading: () => const SizedBox(
                  height: 50,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (summary) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _CountColumn(
                        label: 'Passengers',
                        count: summary.totalPassengers.toString(),
                        color: theme.colorScheme.primary,
                      ),
                      Container(
                          width: 1, height: 30, color: Colors.grey.shade300),
                      _CountColumn(
                        label: 'Pass',
                        count: summary.monthlyPassCount.toString(),
                        color: Colors.teal.shade800,
                      ),
                      Container(
                          width: 1, height: 30, color: Colors.grey.shade300),
                      _CountColumn(
                        label: 'Pay-per-trip',
                        count: summary.payPerTripCount.toString(),
                        color: Colors.deepOrange.shade800,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 18),

            // ── Large Action Buttons (Spec Section 18) ──────────────
            if (trip.isActive) ...[
              // VIEW TRIP Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => context.push(AppRoutes.driverCurrentTrip),
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text(
                    'VIEW LIVE TRIP',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // END TRIP Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade700, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isActionLoading ? null : onEndTrip,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(
                    isActionLoading ? 'Ending Trip...' : 'END TRIP',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ] else if (trip.isScheduled) ...[
              // START TRIP Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isActionLoading ? null : onStartTrip,
                  icon: const Icon(Icons.play_circle_fill_rounded, size: 26),
                  label: Text(
                    isActionLoading ? 'Starting Trip...' : 'START TRIP',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Completed trip badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Trip completed successfully',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoTripTodayCard extends StatelessWidget {
  const _NoTripTodayCard({required this.assignmentAsync});

  final AsyncValue<dynamic> assignmentAsync;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.event_available_rounded,
                size: 48, color: Colors.blueGrey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No Trips Scheduled for Today',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You have no pending trips scheduled today. Your assigned bus and route are ready.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String text;

    switch (status) {
      case 'IN_PROGRESS':
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        text = 'LIVE';
        break;
      case 'SCHEDULED':
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        text = 'SCHEDULED';
        break;
      case 'COMPLETED':
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        text = 'COMPLETED';
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.black87;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _CountColumn extends StatelessWidget {
  const _CountColumn({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final String count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _DriverNavCard extends StatelessWidget {
  const _DriverNavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 28),
        onTap: onTap,
      ),
    );
  }
}
