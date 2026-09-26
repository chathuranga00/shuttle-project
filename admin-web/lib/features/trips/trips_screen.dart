import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../buses/buses_provider.dart';
import '../drivers/drivers_provider.dart';
import '../routes_stops/routes_stops_provider.dart';
import 'trips_provider.dart';

class TripsScreen extends ConsumerStatefulWidget {
  const TripsScreen({super.key});

  @override
  ConsumerState<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends ConsumerState<TripsScreen> {
  String _selectedStatus = 'ALL';
  String _search = '';

  Future<void> _openScheduleDialog() async {
    final routes = await ref.read(routesProvider.future);
    final buses = await ref.read(busesProvider.future);
    final drivers = await ref.read(driversProvider.future);

    int? routeId = routes.isNotEmpty ? routes.first.id : null;
    int? busId = buses.isNotEmpty ? buses.first.id : null;
    int? driverId = drivers.isNotEmpty ? drivers.first.driverId : null;
    final notesCtrl = TextEditingController();
    DateTime departureTime = DateTime.now().add(const Duration(minutes: 30));

    if (!mounted) return;

    final scheduled = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Schedule Transit Trip'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: routeId,
                  decoration: const InputDecoration(labelText: 'Transit Route *'),
                  items: routes.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
                  onChanged: (v) => setStateDialog(() => routeId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: busId,
                  decoration: const InputDecoration(labelText: 'Assigned Bus *'),
                  items: buses.map((b) => DropdownMenuItem(value: b.id, child: Text('${b.busNumber} (${b.plateNumber})'))).toList(),
                  onChanged: (v) => setStateDialog(() => busId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: driverId,
                  decoration: const InputDecoration(labelText: 'Assigned Driver *'),
                  items: drivers.map((d) => DropdownMenuItem(value: d.driverId, child: Text(d.fullName))).toList(),
                  onChanged: (v) => setStateDialog(() => driverId = v),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Departure: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(Formatters.formatDateTime(departureTime), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: departureTime,
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (date != null && ctx.mounted) {
                          final time = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay.fromDateTime(departureTime),
                          );
                          if (time != null) {
                            setStateDialog(() {
                              departureTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                            });
                          }
                        }
                      },
                      child: const Text('Pick Time'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Trip Notes (Optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: (routeId != null && busId != null && driverId != null)
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Schedule Trip'),
            ),
          ],
        ),
      ),
    );

    if (scheduled == true && routeId != null && busId != null && driverId != null) {
      try {
        final api = ref.read(apiClientProvider);
        await api.post(
          ApiEndpoints.trips,
          data: {
            'routeId': routeId,
            'busId': busId,
            'driverId': driverId,
            'scheduledStart': departureTime.toUtc().toIso8601String(),
            'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
          },
        );
        ref.invalidate(tripsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trip scheduled successfully'), backgroundColor: AppTheme.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to schedule trip: $e'), backgroundColor: AppTheme.danger),
          );
        }
      }
    }
  }

  Future<void> _updateTripState(int tripId, String action) async {
    try {
      final api = ref.read(apiClientProvider);
      String endpoint;
      if (action == 'start') {
        endpoint = ApiEndpoints.startTrip(tripId);
      } else if (action == 'complete') {
        endpoint = ApiEndpoints.completeTrip(tripId);
      } else {
        endpoint = ApiEndpoints.cancelTrip(tripId);
      }

      await api.post(endpoint);
      ref.invalidate(tripsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Trip marked as $action'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _deleteTrip(TripItem trip) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Trip'),
        content: Text('Are you sure you want to delete Trip #${trip.id}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.delete(ApiEndpoints.tripById(trip.id));
      ref.invalidate(tripsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Top Controls
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search by route, driver, or bus...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Status Filter Chips
                ...['ALL', 'SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'].map((s) {
                  final isSelected = _selectedStatus == s;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(s, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      onSelected: (_) => setState(() => _selectedStatus = s),
                    ),
                  );
                }),

                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _openScheduleDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Schedule Trip'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Table Card
            Expanded(
              child: Card(
                child: tripsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppTheme.danger))),
                  data: (trips) {
                    final filtered = trips.where((t) {
                      if (_selectedStatus != 'ALL' && t.status.toUpperCase() != _selectedStatus) {
                        return false;
                      }
                      if (_search.isNotEmpty) {
                        return t.routeName.toLowerCase().contains(_search) ||
                            t.driverName.toLowerCase().contains(_search) ||
                            t.busNumber.toLowerCase().contains(_search);
                      }
                      return true;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(child: Text('No trips match filter criteria'));
                    }

                    return SingleChildScrollView(
                      child: SizedBox(
                        width: double.infinity,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('TRIP ID')),
                            DataColumn(label: Text('ROUTE')),
                            DataColumn(label: Text('BUS')),
                            DataColumn(label: Text('DRIVER')),
                            DataColumn(label: Text('SCHEDULED START')),
                            DataColumn(label: Text('ACTUAL TIME')),
                            DataColumn(label: Text('STATUS')),
                            DataColumn(label: Text('ACTIONS')),
                          ],
                          rows: filtered.map((trip) {
                            return DataRow(
                              cells: [
                                DataCell(Text('#${trip.id}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(Text(trip.routeName, style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(Text(trip.busNumber)),
                                DataCell(Text(trip.driverName)),
                                DataCell(Text(Formatters.formatDateTime(trip.scheduledStart))),
                                DataCell(Text(trip.actualStart != null
                                    ? Formatters.formatDateTime(trip.actualStart)
                                    : '-')),
                                DataCell(Formatters.statusBadge(trip.status)),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (trip.isScheduled)
                                        IconButton(
                                          tooltip: 'Start Trip',
                                          icon: const Icon(Icons.play_arrow, size: 18, color: AppTheme.primary),
                                          onPressed: () => _updateTripState(trip.id, 'start'),
                                        ),
                                      if (trip.isInProgress)
                                        IconButton(
                                          tooltip: 'Complete Trip',
                                          icon: const Icon(Icons.check, size: 18, color: AppTheme.success),
                                          onPressed: () => _updateTripState(trip.id, 'complete'),
                                        ),
                                      if (trip.isScheduled || trip.isInProgress)
                                        IconButton(
                                          tooltip: 'Cancel Trip',
                                          icon: const Icon(Icons.cancel_outlined, size: 18, color: AppTheme.warning),
                                          onPressed: () => _updateTripState(trip.id, 'cancel'),
                                        ),
                                      IconButton(
                                        tooltip: 'Delete Trip',
                                        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                                        onPressed: () => _deleteTrip(trip),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
