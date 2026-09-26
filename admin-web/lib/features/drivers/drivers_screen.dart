import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../buses/buses_provider.dart';
import '../routes_stops/routes_stops_provider.dart';
import 'drivers_provider.dart';

class DriversScreen extends ConsumerStatefulWidget {
  const DriversScreen({super.key});

  @override
  ConsumerState<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends ConsumerState<DriversScreen> {
  String _search = '';

  Future<void> _openAddDriverDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: 'Driver@1234');
    final licenseCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Driver'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name *'),
                  validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email Address *'),
                  validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passCtrl,
                  decoration: const InputDecoration(labelText: 'Initial Password *'),
                  validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: licenseCtrl,
                  decoration: const InputDecoration(labelText: 'Driver License Number *'),
                  validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Create Driver'),
          ),
        ],
      ),
    );

    if (created == true) {
      try {
        final api = ref.read(apiClientProvider);
        await api.post(
          ApiEndpoints.drivers,
          data: {
            'fullName': nameCtrl.text.trim(),
            'email': emailCtrl.text.trim(),
            'password': passCtrl.text,
            'licenseNumber': licenseCtrl.text.trim(),
          },
        );
        ref.invalidate(driversProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Driver created successfully'), backgroundColor: AppTheme.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create driver: $e'), backgroundColor: AppTheme.danger),
          );
        }
      }
    }
  }

  Future<void> _openAssignDialog(DriverItem driver) async {
    final busesAsync = await ref.read(busesProvider.future);
    final routesAsync = await ref.read(routesProvider.future);

    int? selectedBusId = driver.assignedBusId;
    int? selectedRouteId = driver.assignedRouteId;

    if (!mounted) return;

    final assigned = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text('Assign Bus & Route: ${driver.fullName}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Bus *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: selectedBusId,
                  decoration: const InputDecoration(hintText: 'Select bus'),
                  items: busesAsync.map((bus) {
                    return DropdownMenuItem<int>(
                      value: bus.id,
                      child: Text('${bus.busNumber} (${bus.plateNumber})'),
                    );
                  }).toList(),
                  onChanged: (v) => setStateDialog(() => selectedBusId = v),
                ),
                const SizedBox(height: 16),
                const Text('Select Route (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: selectedRouteId,
                  decoration: const InputDecoration(hintText: 'Select route'),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('None / Unassigned')),
                    ...routesAsync.map((route) {
                      return DropdownMenuItem<int>(
                        value: route.id,
                        child: Text(route.name),
                      );
                    }),
                  ],
                  onChanged: (v) => setStateDialog(() => selectedRouteId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selectedBusId != null ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Save Assignment'),
            ),
          ],
        ),
      ),
    );

    if (assigned == true && selectedBusId != null) {
      try {
        final api = ref.read(apiClientProvider);
        await api.post(
          ApiEndpoints.assignDriver(driver.driverId),
          data: {
            'busId': selectedBusId,
            'routeId': selectedRouteId,
          },
        );
        ref.invalidate(driversProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Driver assigned successfully'), backgroundColor: AppTheme.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to assign driver: $e'), backgroundColor: AppTheme.danger),
          );
        }
      }
    }
  }

  Future<void> _unassignDriver(DriverItem driver) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.delete(ApiEndpoints.assignDriver(driver.driverId));
      ref.invalidate(driversProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver unassigned'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unassign: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _deleteDriver(DriverItem driver) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Driver'),
        content: Text('Deactivate and remove driver ${driver.fullName}?'),
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
      await api.delete(ApiEndpoints.driverById(driver.driverId));
      ref.invalidate(driversProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver deleted / deactivated'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete driver: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final driversAsync = ref.watch(driversProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Top Bar
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Filter by driver name, license, or email...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _openAddDriverDialog,
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Add Driver'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Drivers Table Card
            Expanded(
              child: Card(
                child: driversAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppTheme.danger))),
                  data: (drivers) {
                    final filtered = drivers.where((d) {
                      if (_search.isEmpty) return true;
                      return d.fullName.toLowerCase().contains(_search) ||
                          d.email.toLowerCase().contains(_search) ||
                          d.licenseNumber.toLowerCase().contains(_search);
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text('No drivers found', style: TextStyle(color: AppTheme.textSecondary)),
                      );
                    }

                    return SingleChildScrollView(
                      child: SizedBox(
                        width: double.infinity,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('NAME')),
                            DataColumn(label: Text('EMAIL')),
                            DataColumn(label: Text('LICENSE')),
                            DataColumn(label: Text('ASSIGNED BUS')),
                            DataColumn(label: Text('ASSIGNED ROUTE')),
                            DataColumn(label: Text('STATUS')),
                            DataColumn(label: Text('ACTIONS')),
                          ],
                          rows: filtered.map((driver) {
                            return DataRow(
                              cells: [
                                DataCell(Text(driver.fullName, style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(Text(driver.email)),
                                DataCell(Text(driver.licenseNumber)),
                                DataCell(
                                  driver.assignedBusNumber != null
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.directions_bus, size: 16, color: AppTheme.primary),
                                            const SizedBox(width: 6),
                                            Text(driver.assignedBusNumber!),
                                          ],
                                        )
                                      : const Text('Unassigned', style: TextStyle(color: AppTheme.textMuted)),
                                ),
                                DataCell(
                                  driver.assignedRouteName != null
                                      ? Text(driver.assignedRouteName!)
                                      : const Text('-', style: TextStyle(color: AppTheme.textMuted)),
                                ),
                                DataCell(Formatters.statusBadge(driver.driverStatus)),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Assign Bus / Route',
                                        icon: const Icon(Icons.assignment_ind_outlined, size: 18, color: AppTheme.primary),
                                        onPressed: () => _openAssignDialog(driver),
                                      ),
                                      if (driver.isAssigned)
                                        IconButton(
                                          tooltip: 'Unassign Bus',
                                          icon: const Icon(Icons.link_off, size: 18, color: AppTheme.warning),
                                          onPressed: () => _unassignDriver(driver),
                                        ),
                                      IconButton(
                                        tooltip: 'Delete Driver',
                                        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                                        onPressed: () => _deleteDriver(driver),
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
