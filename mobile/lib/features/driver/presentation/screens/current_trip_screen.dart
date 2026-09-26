import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/driver_location_service.dart';
import '../../data/models/driver_trip.dart';
import '../providers/driver_providers.dart';

/// Screen displaying the active or scheduled trip with real-time boarding feed.
/// Per spec section 18:
/// - Large buttons and high-contrast simple UI for in-cab operation.
/// - Auto-refreshes live boarding feed every 10 seconds.
/// - Allows driver to start/end their assigned trip.
class CurrentTripScreen extends ConsumerStatefulWidget {
  const CurrentTripScreen({super.key});

  @override
  ConsumerState<CurrentTripScreen> createState() => _CurrentTripScreenState();
}

class _CurrentTripScreenState extends ConsumerState<CurrentTripScreen> {
  bool _isActionInProgress = false;

  Future<void> _handleStartTrip(DriverTrip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Trip?'),
        content: Text(
          'Start trip for Route "${trip.routeName}" with Bus ${trip.busNumber}?\n\n'
          'Students will be able to board and validate immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Start Trip'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isActionInProgress = true);
    final success = await ref
        .read(driverActionControllerProvider.notifier)
        .startTrip(trip.id);
    if (!mounted) return;
    setState(() => _isActionInProgress = false);

    if (success) {
      ref.read(driverLocationServiceProvider.notifier).startTracking(trip.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip started successfully! Live boarding & GPS sharing are now active.'),
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
        title: const Text('End Current Trip?'),
        content: Text(
          'Are you sure you want to end the trip for "${trip.routeName}"?\n\n'
          'Once ended, no further boardings can be recorded for this trip.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Trip Active'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & End Trip'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isActionInProgress = true);
    final success = await ref
        .read(driverActionControllerProvider.notifier)
        .endTrip(trip.id);
    if (!mounted) return;
    setState(() => _isActionInProgress = false);

    if (success) {
      ref.read(driverLocationServiceProvider.notifier).stopTracking();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip completed and closed successfully.'),
          backgroundColor: Colors.blueGrey,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to end trip. Please check your connection.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentTripAsync = ref.watch(currentTripProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Current Trip'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(currentTripProvider),
          ),
        ],
      ),
      body: currentTripAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'Could not load trip details',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(currentTripProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (trip) {
          if (trip == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_bus_outlined,
                        size: 72, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                    const SizedBox(height: 20),
                    Text(
                      'No Active Trip Today',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'You do not have any trips scheduled or in-progress for today.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Return to Dashboard'),
                    ),
                  ],
                ),
              ),
            );
          }

          // If trip is currently active, ensure location sharing is started
          if (trip.isActive) {
            final locState = ref.watch(driverLocationServiceProvider);
            if (!locState.isSharing && !locState.isPermissionDenied && !locState.isGpsServiceDisabled) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(driverLocationServiceProvider.notifier).startTracking(trip.id);
              });
            }
          }

          return _TripDetailsView(
            trip: trip,
            isActionInProgress: _isActionInProgress,
            onStartTrip: () => _handleStartTrip(trip),
            onEndTrip: () => _handleEndTrip(trip),
          );
        },
      ),
    );
  }
}

class _TripDetailsView extends ConsumerWidget {
  const _TripDetailsView({
    required this.trip,
    required this.isActionInProgress,
    required this.onStartTrip,
    required this.onEndTrip,
  });

  final DriverTrip trip;
  final bool isActionInProgress;
  final VoidCallback onStartTrip;
  final VoidCallback onEndTrip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summaryAsync = ref.watch(liveTripSummaryProvider(trip.id));

    return Column(
      children: [
        // ── Top Trip Info Card ─────────────────────────────────────────
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      trip.routeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _StatusPill(status: trip.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.directions_bus_rounded,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Bus ${trip.busNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (trip.scheduledStart != null) ...[
                    const Icon(Icons.schedule_rounded,
                        color: Colors.white70, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat.jm().format(trip.scheduledStart!),
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // ── Auto-refresh live status bar ───────────────────────────────
        if (trip.isActive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.green.shade50,
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'LIVE • Auto-refreshing every 10s',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat.jms().format(DateTime.now()),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

        // ── Persistent Location Sharing Indicator (Near real-time GPS) ─
        if (trip.isActive)
          _LocationSharingIndicator(trip: trip),

        // ── Metric Tiles Row ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: summaryAsync.when(
            loading: () => const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Live passenger metrics temporarily unavailable'),
            ),
            data: (summary) => Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    title: 'Total',
                    value: summary.totalPassengers.toString(),
                    icon: Icons.people_alt_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    title: 'Pass',
                    value: summary.monthlyPassCount.toString(),
                    icon: Icons.card_membership_rounded,
                    color: Colors.teal.shade700,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    title: 'Pay-per-trip',
                    value: summary.payPerTripCount.toString(),
                    icon: Icons.payments_outlined,
                    color: Colors.deepOrange.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Boarding Feed Header ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Boardings',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (summaryAsync.hasValue)
                Text(
                  '${summaryAsync.value!.recentBoardings.length} recorded',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
            ],
          ),
        ),

        // ── Boarding List ──────────────────────────────────────────────
        Expanded(
          child: summaryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text('Error loading boardings: $err'),
            ),
            data: (summary) {
              final boardings = summary.recentBoardings;
              if (boardings.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.how_to_reg_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          trip.isActive
                              ? 'Waiting for passengers to board...'
                              : 'No passengers boarded yet',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: boardings.length,
                itemBuilder: (context, index) {
                  final b = boardings[index];
                  final isPass = b.isMonthlyPass;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: isPass
                            ? Colors.teal.shade50
                            : Colors.orange.shade50,
                        child: Icon(
                          isPass
                              ? Icons.badge_outlined
                              : Icons.account_balance_wallet_outlined,
                          color: isPass
                              ? Colors.teal.shade700
                              : Colors.orange.shade800,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        b.studentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              b.stopName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            DateFormat.jm().format(b.boardedAt),
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isPass
                              ? Colors.teal.shade100
                              : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isPass ? 'PASS' : 'PAID',
                          style: TextStyle(
                            color: isPass
                                ? Colors.teal.shade900
                                : Colors.orange.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // ── Large In-Cab Action Button ─────────────────────────────────
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 60, // Per spec section 18: large buttons
              child: trip.isActive
                  ? ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: isActionInProgress ? null : onEndTrip,
                      icon: isActionInProgress
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.stop_circle_rounded, size: 28),
                      label: Text(
                        isActionInProgress ? 'Ending Trip...' : 'END TRIP',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    )
                  : trip.isScheduled
                      ? ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: isActionInProgress ? null : onStartTrip,
                          icon: isActionInProgress
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.play_circle_fill_rounded,
                                  size: 28),
                          label: Text(
                            isActionInProgress
                                ? 'Starting Trip...'
                                : 'START TRIP',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        )
                      : Container(
                          alignment: Alignment.center,
                          child: Text(
                            'Trip is Completed',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'IN_PROGRESS':
        bg = Colors.green.shade400;
        fg = Colors.green.shade900;
        label = 'ACTIVE';
        break;
      case 'SCHEDULED':
        bg = Colors.amber.shade300;
        fg = Colors.brown.shade900;
        label = 'SCHEDULED';
        break;
      case 'COMPLETED':
        bg = Colors.grey.shade400;
        fg = Colors.black87;
        label = 'COMPLETED';
        break;
      default:
        bg = Colors.white24;
        fg = Colors.white;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationSharingIndicator extends ConsumerWidget {
  const _LocationSharingIndicator({required this.trip});

  final DriverTrip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverLocationServiceProvider);

    if (state.isPermissionDenied) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade400),
        ),
        child: Row(
          children: [
            Icon(Icons.location_off_rounded, color: Colors.amber.shade900, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location permission denied',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Students cannot see this bus on the map.',
                    style: TextStyle(color: Colors.amber.shade800, fontSize: 11),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                ref.read(driverLocationServiceProvider.notifier).startTracking(trip.id);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    if (state.isGpsServiceDisabled) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade400),
        ),
        child: Row(
          children: [
            Icon(Icons.gps_off_rounded, color: Colors.orange.shade900, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Phone GPS is turned off. Please enable device location.',
                style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    final lastSent = state.lastSentTime;
    final timeStr = lastSent != null
        ? DateFormat.jms().format(lastSent)
        : 'Starting...';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.teal.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.teal.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.share_location_rounded,
              color: Colors.teal,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'Sharing location',
                      style: TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      '• GPS Active',
                      style: TextStyle(
                        color: Colors.teal,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Students see live bus position • Last sent: $timeStr',
                  style: TextStyle(color: Colors.teal.shade700, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.teal,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

