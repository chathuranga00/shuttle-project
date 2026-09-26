import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/driver_providers.dart';

/// Screen displaying the driver's currently assigned vehicle details.
/// Spec Section 18: Simple, large-touch UI.
class AssignedBusScreen extends ConsumerWidget {
  const AssignedBusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final assignmentAsync = ref.watch(driverAssignmentProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assigned Bus'),
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
                Text('Could not load bus details', style: theme.textTheme.titleMedium),
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
          final bus = assignment.bus;
          if (bus == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_bus_outlined,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No Bus Currently Assigned',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please contact the shuttle operations desk to assign a vehicle to your shift.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Main Bus Hero Card ─────────────────────────────
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor:
                              theme.colorScheme.primary.withValues(alpha: 0.1),
                          child: Icon(
                            Icons.directions_bus_filled_rounded,
                            size: 42,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Bus ${bus.busNumber}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            bus.status,
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Vehicle Specifications',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                _SpecTile(
                  icon: Icons.pin_outlined,
                  label: 'Registration Plate',
                  value: bus.plateNumber.isNotEmpty ? bus.plateNumber : 'N/A',
                ),
                _SpecTile(
                  icon: Icons.airline_seat_recline_normal_rounded,
                  label: 'Seating Capacity',
                  value: '${bus.capacity} Passengers',
                ),
                _SpecTile(
                  icon: Icons.badge_outlined,
                  label: 'Driver in Charge',
                  value: assignment.driverName,
                ),
                _SpecTile(
                  icon: Icons.credit_card_rounded,
                  label: 'Driver License',
                  value: assignment.licenseNumber,
                ),

                const SizedBox(height: 24),
                // ── Inspection / Safety Notice ─────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined,
                          color: Colors.blue.shade800, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Verify vehicle mirrors, emergency exits, and first-aid kit before starting each trip.',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SpecTile extends StatelessWidget {
  const _SpecTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.blueGrey.shade700, size: 22),
        ),
        title: Text(label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
