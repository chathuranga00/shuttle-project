import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import 'routes_stops_provider.dart';

class RoutesStopsScreen extends ConsumerStatefulWidget {
  const RoutesStopsScreen({super.key});

  @override
  ConsumerState<RoutesStopsScreen> createState() => _RoutesStopsScreenState();
}

class _RoutesStopsScreenState extends ConsumerState<RoutesStopsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int? _selectedRouteId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Stops Management Dialogs
  // ---------------------------------------------------------------------------

  Future<void> _openStopDialog([StopItem? stop]) async {
    final isEdit = stop != null;
    final nameCtrl = TextEditingController(text: stop?.name ?? '');
    final codeCtrl = TextEditingController(text: stop?.qrCode ?? '');
    final latCtrl = TextEditingController(text: stop?.latitude?.toString() ?? '6.9271');
    final lngCtrl = TextEditingController(text: stop?.longitude?.toString() ?? '79.8612');
    final addressCtrl = TextEditingController(text: stop?.address ?? '');
    String status = stop?.status ?? 'ACTIVE';
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(isEdit ? 'Edit Stop: ${stop.name}' : 'Create Bus Stop'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Stop Name *'),
                      validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(labelText: 'Stop Code (e.g. STOP-001)'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: latCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Latitude *'),
                            validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: lngCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Longitude *'),
                            validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(labelText: 'Address / Landmark'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE')),
                        DropdownMenuItem(value: 'INACTIVE', child: Text('INACTIVE')),
                      ],
                      onChanged: (v) => setStateDialog(() => status = v ?? 'ACTIVE'),
                    ),
                  ],
                ),
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
              child: Text(isEdit ? 'Save Changes' : 'Create Stop'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      try {
        final api = ref.read(apiClientProvider);
        final payload = {
          'name': nameCtrl.text.trim(),
          'qrCode': codeCtrl.text.trim().isNotEmpty ? codeCtrl.text.trim() : null,
          'latitude': double.parse(latCtrl.text.trim()),
          'longitude': double.parse(lngCtrl.text.trim()),
          'address': addressCtrl.text.trim(),
          'status': status,
        };

        if (isEdit) {
          await api.put(ApiEndpoints.stopById(stop.id), data: payload);
        } else {
          await api.post(ApiEndpoints.stops, data: payload);
        }

        ref.invalidate(stopsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEdit ? 'Stop updated' : 'Stop created'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.danger),
          );
        }
      }
    }
  }

  Future<void> _deleteStop(StopItem stop) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Stop'),
        content: Text('Delete stop ${stop.name}?'),
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
      await api.delete(ApiEndpoints.stopById(stop.id));
      ref.invalidate(stopsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Route Management Dialogs
  // ---------------------------------------------------------------------------

  Future<void> _openRouteDialog([RouteItem? route]) async {
    final isEdit = route != null;
    final allStops = await ref.read(stopsProvider.future);
    final nameCtrl = TextEditingController(text: route?.name ?? '');
    final codeCtrl = TextEditingController(text: route?.code ?? '');
    final descCtrl = TextEditingController(text: route?.description ?? '');
    final durationCtrl = TextEditingController(text: route?.estimatedDurationMinutes?.toString() ?? '30');
    String status = route?.status ?? 'ACTIVE';

    List<Map<String, dynamic>> routeStops = [];
    if (route != null) {
      for (final s in route.stops) {
        routeStops.add({
          'busStopId': s.stopId,
          'stopOrder': s.stopOrder,
          'estimatedOffsetMinutes': s.estimatedOffsetMinutes ?? 0,
        });
      }
    }

    if (!mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(isEdit ? 'Edit Route: ${route.name}' : 'Create New Route'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Route Name *'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: codeCtrl,
                          decoration: const InputDecoration(labelText: 'Route Code (e.g. RT-01) *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: durationCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Est. Duration (mins)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Ordered Stops', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),

                  // Stop rows
                  ...routeStops.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceMuted,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Text('#${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: item['busStopId'] as int?,
                              hint: const Text('Select stop'),
                              items: allStops.map((s) {
                                return DropdownMenuItem<int>(
                                  value: s.id,
                                  child: Text(s.name, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (v) {
                                setStateDialog(() {
                                  item['busStopId'] = v;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 70,
                            child: TextFormField(
                              initialValue: item['estimatedOffsetMinutes'].toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: '+Mins', contentPadding: EdgeInsets.all(6)),
                              onChanged: (v) => item['estimatedOffsetMinutes'] = int.tryParse(v) ?? 0,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AppTheme.danger, size: 20),
                            onPressed: () {
                              setStateDialog(() {
                                routeStops.removeAt(idx);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),

                  TextButton.icon(
                    onPressed: () {
                      setStateDialog(() {
                        routeStops.add({
                          'busStopId': allStops.isNotEmpty ? allStops.first.id : null,
                          'stopOrder': routeStops.length + 1,
                          'estimatedOffsetMinutes': 5 * routeStops.length,
                        });
                      });
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Stop to Route'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isEdit ? 'Update Route' : 'Create Route'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      try {
        final api = ref.read(apiClientProvider);
        final orderedList = routeStops.asMap().entries.map((entry) {
          return {
            'busStopId': entry.value['busStopId'],
            'stopOrder': entry.key + 1,
            'estimatedOffsetMinutes': entry.value['estimatedOffsetMinutes'],
          };
        }).toList();

        final payload = {
          'name': nameCtrl.text.trim(),
          'code': codeCtrl.text.trim(),
          'description': descCtrl.text.trim(),
          'estimatedDurationMinutes': int.tryParse(durationCtrl.text.trim()),
          'status': status,
          'stops': orderedList,
        };

        if (isEdit) {
          await api.put(ApiEndpoints.routeById(route.id), data: payload);
        } else {
          await api.post(ApiEndpoints.routes, data: payload);
        }

        ref.invalidate(routesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEdit ? 'Route updated successfully' : 'Route created successfully'),
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

  Future<void> _deleteRoute(RouteItem route) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Route'),
        content: Text('Are you sure you want to delete route ${route.name}?'),
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
      await api.delete(ApiEndpoints.routeById(route.id));
      ref.invalidate(routesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Fares Management Dialogs
  // ---------------------------------------------------------------------------

  Future<void> _openFareDialog([FareItem? fare]) async {
    final isEdit = fare != null;
    final routes = await ref.read(routesProvider.future);
    final stops = await ref.read(stopsProvider.future);

    int? routeId = fare?.routeId ?? (routes.isNotEmpty ? routes.first.id : null);
    int? stopId = fare?.stopId ?? (stops.isNotEmpty ? stops.first.id : null);
    final amountCtrl = TextEditingController(text: fare?.amount.toString() ?? '50.00');
    String fareClass = fare?.fareClass ?? 'STANDARD';
    final fromCtrl = TextEditingController(
      text: fare?.effectiveFrom ?? Formatters.formatDate(DateTime.now()),
    );

    if (!mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(isEdit ? 'Edit Fare' : 'Add Stop Fare'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: routeId,
                  decoration: const InputDecoration(labelText: 'Route *'),
                  items: routes.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
                  onChanged: (v) => setStateDialog(() => routeId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: stopId,
                  decoration: const InputDecoration(labelText: 'Bus Stop *'),
                  items: stops.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                  onChanged: (v) => setStateDialog(() => stopId = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Fare Amount (LKR) *'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: fareClass,
                  decoration: const InputDecoration(labelText: 'Fare Class *'),
                  items: const [
                    DropdownMenuItem(value: 'STANDARD', child: Text('STANDARD')),
                    DropdownMenuItem(value: 'STUDENT', child: Text('STUDENT')),
                    DropdownMenuItem(value: 'STAFF', child: Text('STAFF')),
                  ],
                  onChanged: (v) => setStateDialog(() => fareClass = v ?? 'STANDARD'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: fromCtrl,
                  decoration: const InputDecoration(labelText: 'Effective From (YYYY-MM-DD) *'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isEdit ? 'Save Changes' : 'Create Fare'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && routeId != null && stopId != null) {
      try {
        final api = ref.read(apiClientProvider);
        final payload = {
          'routeId': routeId,
          'stopId': stopId,
          'amount': double.parse(amountCtrl.text.trim()),
          'fareClass': fareClass,
          'effectiveFrom': fromCtrl.text.trim(),
        };

        if (isEdit) {
          await api.put(ApiEndpoints.fareById(fare.id), data: payload);
        } else {
          await api.post(ApiEndpoints.fares, data: payload);
        }

        ref.invalidate(faresProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fare saved successfully'), backgroundColor: AppTheme.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save fare: $e'), backgroundColor: AppTheme.danger),
          );
        }
      }
    }
  }

  Future<void> _deleteFare(FareItem fare) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.delete(ApiEndpoints.fareById(fare.id));
      ref.invalidate(faresProvider);
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
    final routesAsync = ref.watch(routesProvider);
    final stopsAsync = ref.watch(stopsProvider);
    final faresAsync = ref.watch(faresProvider(_selectedRouteId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Tabs Bar
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textSecondary,
                indicatorColor: AppTheme.primary,
                tabs: const [
                  Tab(icon: Icon(Icons.alt_route, size: 18), text: 'Transit Routes & Ordered Stops'),
                  Tab(icon: Icon(Icons.place, size: 18), text: 'Bus Stops Directory'),
                  Tab(icon: Icon(Icons.attach_money, size: 18), text: 'Route Fares'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 1. Routes Tab
                  _buildRoutesTab(routesAsync),

                  // 2. Stops Tab
                  _buildStopsTab(stopsAsync),

                  // 3. Fares Tab
                  _buildFaresTab(faresAsync, routesAsync),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutesTab(AsyncValue<List<RouteItem>> routesAsync) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Configured Transit Routes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            ElevatedButton.icon(
              onPressed: () => _openRouteDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create New Route'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: routesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppTheme.danger))),
              data: (routes) {
                if (routes.isEmpty) {
                  return const Center(child: Text('No routes configured yet'));
                }

                return ListView.separated(
                  itemCount: routes.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final route = routes[index];
                    return ExpansionTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppTheme.surfaceMuted,
                        child: Icon(Icons.route, color: AppTheme.primary, size: 20),
                      ),
                      title: Row(
                        children: [
                          Text(route.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceMuted,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(route.code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          Formatters.statusBadge(route.status),
                        ],
                      ),
                      subtitle: Text(
                        '${route.stops.length} ordered stops • Est. ${route.estimatedDurationMinutes ?? 30} mins',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                            onPressed: () => _openRouteDialog(route),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                            onPressed: () => _deleteRoute(route),
                          ),
                        ],
                      ),
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          color: AppTheme.surfaceMuted.withValues(alpha: 0.5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Stop Sequence:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: route.stops.map((s) {
                                  return Chip(
                                    avatar: CircleAvatar(
                                      backgroundColor: AppTheme.primary,
                                      child: Text(
                                        '${s.stopOrder}',
                                        style: const TextStyle(color: Colors.white, fontSize: 10),
                                      ),
                                    ),
                                    label: Text('${s.stopName} (+${s.estimatedOffsetMinutes ?? 0}m)'),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStopsTab(AsyncValue<List<StopItem>> stopsAsync) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Physical Bus Stops', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ElevatedButton.icon(
              onPressed: () => _openStopDialog(),
              icon: const Icon(Icons.add_location_alt, size: 18),
              label: const Text('Add Bus Stop'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: stopsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppTheme.danger))),
              data: (stops) {
                if (stops.isEmpty) return const Center(child: Text('No stops found'));

                return SingleChildScrollView(
                  child: SizedBox(
                    width: double.infinity,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('STOP NAME')),
                        DataColumn(label: Text('STOP CODE')),
                        DataColumn(label: Text('GPS COORDINATES')),
                        DataColumn(label: Text('ADDRESS / LANDMARK')),
                        DataColumn(label: Text('STATUS')),
                        DataColumn(label: Text('ACTIONS')),
                      ],
                      rows: stops.map((stop) {
                        return DataRow(
                          cells: [
                            DataCell(Text(stop.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                            DataCell(Text(stop.qrCode)),
                            DataCell(Text('${stop.latitude?.toStringAsFixed(4) ?? "-"}, ${stop.longitude?.toStringAsFixed(4) ?? "-"}')),
                            DataCell(Text(stop.address ?? '-')),
                            DataCell(Formatters.statusBadge(stop.status)),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                                    onPressed: () => _openStopDialog(stop),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                                    onPressed: () => _deleteStop(stop),
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
    );
  }

  Widget _buildFaresTab(AsyncValue<List<FareItem>> faresAsync, AsyncValue<List<RouteItem>> routesAsync) {
    return Column(
      children: [
        Row(
          children: [
            routesAsync.maybeWhen(
              data: (routes) => DropdownButton<int?>(
                value: _selectedRouteId,
                hint: const Text('Filter by Route (All Routes)'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('All Routes')),
                  ...routes.map((r) => DropdownMenuItem<int?>(value: r.id, child: Text(r.name))),
                ],
                onChanged: (v) => setState(() => _selectedRouteId = v),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _openFareDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Fare Rule'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: faresAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppTheme.danger))),
              data: (fares) {
                if (fares.isEmpty) return const Center(child: Text('No fares configured for this route'));

                return SingleChildScrollView(
                  child: SizedBox(
                    width: double.infinity,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('ROUTE')),
                        DataColumn(label: Text('STOP')),
                        DataColumn(label: Text('CLASS')),
                        DataColumn(label: Text('AMOUNT')),
                        DataColumn(label: Text('EFFECTIVE FROM')),
                        DataColumn(label: Text('ACTIONS')),
                      ],
                      rows: fares.map((fare) {
                        return DataRow(
                          cells: [
                            DataCell(Text(fare.routeName ?? 'Route #${fare.routeId}')),
                            DataCell(Text(fare.stopName ?? 'Stop #${fare.stopId}')),
                            DataCell(Text(fare.fareClass)),
                            DataCell(Text(
                              Formatters.formatCurrency(fare.amount),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            )),
                            DataCell(Text(fare.effectiveFrom)),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                                    onPressed: () => _openFareDialog(fare),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                                    onPressed: () => _deleteFare(fare),
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
    );
  }
}
