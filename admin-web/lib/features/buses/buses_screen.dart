import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import 'buses_provider.dart';

class BusesScreen extends ConsumerStatefulWidget {
  const BusesScreen({super.key});

  @override
  ConsumerState<BusesScreen> createState() => _BusesScreenState();
}

class _BusesScreenState extends ConsumerState<BusesScreen> {
  String _search = '';

  Future<void> _openBusDialog([BusItem? bus]) async {
    final isEdit = bus != null;
    final busNumCtrl = TextEditingController(text: bus?.busNumber ?? '');
    final plateCtrl = TextEditingController(text: bus?.plateNumber ?? '');
    final capacityCtrl = TextEditingController(text: bus?.capacity.toString() ?? '40');
    final modelCtrl = TextEditingController(text: bus?.model ?? 'Isuzu Journey');
    String status = bus?.status ?? 'ACTIVE';
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(isEdit ? 'Edit Bus: ${bus.busNumber}' : 'Register New Bus'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: busNumCtrl,
                    decoration: const InputDecoration(labelText: 'Bus Number / Identifier *'),
                    validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: plateCtrl,
                    decoration: const InputDecoration(labelText: 'License Plate Number *'),
                    validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: capacityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Seating Capacity *'),
                    validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'Enter valid capacity' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: modelCtrl,
                    decoration: const InputDecoration(labelText: 'Bus Model'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE')),
                      DropdownMenuItem(value: 'MAINTENANCE', child: Text('MAINTENANCE')),
                      DropdownMenuItem(value: 'RETIRED', child: Text('RETIRED')),
                    ],
                    onChanged: (v) => setStateDialog(() => status = v ?? 'ACTIVE'),
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
              child: Text(isEdit ? 'Save Changes' : 'Register Bus'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      try {
        final api = ref.read(apiClientProvider);
        final payload = {
          'busNumber': busNumCtrl.text.trim(),
          'plateNumber': plateCtrl.text.trim(),
          'capacity': int.parse(capacityCtrl.text.trim()),
          'model': modelCtrl.text.trim(),
          'status': status,
        };

        if (isEdit) {
          await api.put(ApiEndpoints.busById(bus.id), data: payload);
        } else {
          await api.post(ApiEndpoints.buses, data: payload);
        }

        ref.invalidate(busesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEdit ? 'Bus updated successfully' : 'Bus registered successfully'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Operation failed: $e'), backgroundColor: AppTheme.danger),
          );
        }
      }
    }
  }

  Future<void> _deleteBus(BusItem bus) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Bus'),
        content: Text('Are you sure you want to remove bus ${bus.busNumber}?'),
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
      await api.delete(ApiEndpoints.busById(bus.id));
      ref.invalidate(busesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bus removed'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete bus: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busesAsync = ref.watch(busesProvider);

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
                        hintText: 'Filter by bus number, plate, or model...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _openBusDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Register Bus'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Table Card
            Expanded(
              child: Card(
                child: busesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppTheme.danger))),
                  data: (buses) {
                    final filtered = buses.where((b) {
                      if (_search.isEmpty) return true;
                      return b.busNumber.toLowerCase().contains(_search) ||
                          b.plateNumber.toLowerCase().contains(_search) ||
                          (b.model?.toLowerCase().contains(_search) ?? false);
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text('No buses found', style: TextStyle(color: AppTheme.textSecondary)),
                      );
                    }

                    return SingleChildScrollView(
                      child: SizedBox(
                        width: double.infinity,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('BUS NUMBER')),
                            DataColumn(label: Text('PLATE NUMBER')),
                            DataColumn(label: Text('CAPACITY')),
                            DataColumn(label: Text('MODEL')),
                            DataColumn(label: Text('STATUS')),
                            DataColumn(label: Text('ACTIONS')),
                          ],
                          rows: filtered.map((bus) {
                            return DataRow(
                              cells: [
                                DataCell(Text(bus.busNumber, style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(Text(bus.plateNumber)),
                                DataCell(Text('${bus.capacity} seats')),
                                DataCell(Text(bus.model ?? '-')),
                                DataCell(Formatters.statusBadge(bus.status)),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Edit Bus',
                                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                                        onPressed: () => _openBusDialog(bus),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete Bus',
                                        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                                        onPressed: () => _deleteBus(bus),
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
