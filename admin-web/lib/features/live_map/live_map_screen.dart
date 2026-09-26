import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_theme.dart';
import 'data/live_map_service.dart';
import 'models/live_bus_location.dart';

class LiveMapScreen extends ConsumerStatefulWidget {
  const LiveMapScreen({super.key});

  @override
  ConsumerState<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends ConsumerState<LiveMapScreen> {
  final MapController _mapController = MapController();
  int? _selectedBusId;
  bool _hasInitialCentered = false;

  void _centerOnBus(LiveBusLocation bus) {
    setState(() => _selectedBusId = bus.busId);
    _mapController.move(
      LatLng(bus.latitude, bus.longitude),
      15.0,
    );
  }

  void _fitAllBuses(List<LiveBusLocation> buses) {
    if (buses.isEmpty) return;
    if (buses.length == 1) {
      _centerOnBus(buses.first);
      return;
    }

    double minLat = buses.first.latitude;
    double maxLat = buses.first.latitude;
    double minLng = buses.first.longitude;
    double maxLng = buses.first.longitude;

    for (final b in buses) {
      if (b.latitude < minLat) minLat = b.latitude;
      if (b.latitude > maxLat) maxLat = b.latitude;
      if (b.longitude < minLng) minLng = b.longitude;
      if (b.longitude > maxLng) maxLng = b.longitude;
    }

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(80),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 5) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final locationsStream = ref.watch(liveMapLocationsStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: locationsStream.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Connecting to live fleet tracking...',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
              const SizedBox(height: 12),
              Text(
                'Failed to load live fleet tracking: $err',
                style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(liveMapLocationsStreamProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (locationsMap) {
          final buses = locationsMap.values.toList();

          // Auto-center once if we have buses and haven't centered yet
          if (!_hasInitialCentered && buses.isNotEmpty) {
            _hasInitialCentered = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fitAllBuses(buses);
            });
          }

          final initialCenter = buses.isNotEmpty
              ? LatLng(buses.first.latitude, buses.first.longitude)
              : const LatLng(6.9271, 79.8612); // Colombo default

          return Row(
            children: [
              // Left Sidebar: Active buses list & stats
              Container(
                width: 360,
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(right: BorderSide(color: AppTheme.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppTheme.border)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.radar, color: AppTheme.primary, size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    'Active Fleet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.successLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircleAvatar(
                                      radius: 4,
                                      backgroundColor: AppTheme.success,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${buses.length} Active',
                                      style: const TextStyle(
                                        color: AppTheme.success,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Real-time GPS tracking from active driver devices.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: buses.isNotEmpty ? () => _fitAllBuses(buses) : null,
                                icon: const Icon(Icons.zoom_out_map, size: 16),
                                label: const Text('Fit All Buses'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Refresh Snapshot',
                                icon: const Icon(Icons.refresh, size: 20),
                                onPressed: () => ref.invalidate(liveMapLocationsStreamProvider),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Bus List
                    Expanded(
                      child: buses.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.directions_bus_outlined,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No Active Buses',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'There are currently no active trips in transit. Once a driver starts a trip, the bus location will appear here automatically.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: buses.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final bus = buses[index];
                                final isSelected = _selectedBusId == bus.busId;

                                return InkWell(
                                  onTap: () => _centerOnBus(bus),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppTheme.primaryLight.withValues(alpha: 0.08)
                                          : AppTheme.surfaceMuted,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected ? AppTheme.primary : AppTheme.border,
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primary,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.directions_bus,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    bus.busNumber,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 14,
                                                      color: AppTheme.textPrimary,
                                                    ),
                                                  ),
                                                  if (bus.plateNumber != null)
                                                    Text(
                                                      bus.plateNumber!,
                                                      style: const TextStyle(
                                                        color: AppTheme.textSecondary,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            if (bus.speedKmh != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: AppTheme.border),
                                                ),
                                                child: Text(
                                                  '${bus.speedKmh!.toStringAsFixed(0)} km/h',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                    color: AppTheme.primary,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        if (bus.routeName != null)
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.alt_route,
                                                size: 14,
                                                color: AppTheme.textMuted,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  bus.routeName!,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppTheme.textPrimary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Updated ${_formatTimeAgo(bus.updatedAt)}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textMuted,
                                              ),
                                            ),
                                            Text(
                                              '${bus.latitude.toStringAsFixed(4)}, ${bus.longitude.toStringAsFixed(4)}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),

              // Right Area: Map
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: initialCenter,
                        initialZoom: 13.0,
                        minZoom: 4.0,
                        maxZoom: 18.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'dev.shuttle.admin_web',
                        ),
                        MarkerLayer(
                          markers: buses.map((bus) {
                            final isSelected = _selectedBusId == bus.busId;
                            return Marker(
                              point: LatLng(bus.latitude, bus.longitude),
                              width: 140,
                              height: 60,
                              child: GestureDetector(
                                onTap: () => _centerOnBus(bus),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Pill Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryDark
                                            : AppTheme.sidebarBg,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            bus.busNumber,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                          if (bus.speedKmh != null) ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              '${bus.speedKmh!.toStringAsFixed(0)}k',
                                              style: const TextStyle(
                                                color: AppTheme.sidebarActiveBorder,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    // Pointer Icon
                                    Transform.rotate(
                                      angle: (bus.heading ?? 0) * (math.pi / 180),
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppTheme.primaryLight
                                              : AppTheme.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                        child: Icon(
                                          bus.heading != null
                                              ? Icons.navigation
                                              : Icons.directions_bus,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),

                    // Map Controls (Floating Top-Right)
                    Positioned(
                      top: 20,
                      right: 20,
                      child: Column(
                        children: [
                          _MapFloatingButton(
                            icon: Icons.add,
                            tooltip: 'Zoom In',
                            onPressed: () {
                              final current = _mapController.camera;
                              _mapController.move(current.center, current.zoom + 1);
                            },
                          ),
                          const SizedBox(height: 8),
                          _MapFloatingButton(
                            icon: Icons.remove,
                            tooltip: 'Zoom Out',
                            onPressed: () {
                              final current = _mapController.camera;
                              _mapController.move(current.center, current.zoom - 1);
                            },
                          ),
                          const SizedBox(height: 8),
                          _MapFloatingButton(
                            icon: Icons.my_location,
                            tooltip: 'Fit All Buses',
                            onPressed: buses.isNotEmpty ? () => _fitAllBuses(buses) : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MapFloatingButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _MapFloatingButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: AppTheme.textPrimary),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
