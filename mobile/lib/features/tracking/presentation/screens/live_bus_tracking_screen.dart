import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../routes/data/models/route_stop_with_fare.dart';
import '../../../routes/presentation/providers/route_provider.dart';
import '../../data/live_tracking_service.dart';
import '../../data/models/active_trip.dart';
import '../../data/models/live_bus_location.dart';

const Color _primaryNavy = Color(0xFF1A3A6B);

class LiveBusTrackingScreen extends ConsumerStatefulWidget {
  const LiveBusTrackingScreen({
    super.key,
    this.tripId,
    this.routeId,
    this.routeName,
  });

  final int? tripId;
  final int? routeId;
  final String? routeName;

  @override
  ConsumerState<LiveBusTrackingScreen> createState() => _LiveBusTrackingScreenState();
}

class _LiveBusTrackingScreenState extends ConsumerState<LiveBusTrackingScreen> {
  final MapController _mapController = MapController();
  int? _selectedTripId;
  int? _selectedRouteId;
  String? _selectedRouteName;
  Timer? _tickerTimer;
  DateTime? _lastReceivedAt;
  bool _hasInitialCentered = false;

  @override
  void initState() {
    super.initState();
    _selectedTripId = widget.tripId;
    _selectedRouteId = widget.routeId;
    _selectedRouteName = widget.routeName;

    // Ticker every second to update "last updated X seconds ago"
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  String _formatTimeAgo(DateTime? time) {
    if (time == null) return 'Never';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 5) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds} seconds ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
    return '${diff.inHours} hours ago';
  }

  void _centerOnLocation(double lat, double lng) {
    _mapController.move(LatLng(lat, lng), 15.5);
  }

  @override
  Widget build(BuildContext context) {
    final activeTripsAsync = ref.watch(activeTripsProvider);

    // If tripId was not provided initially, auto-select the first active trip if available
    if (_selectedTripId == null) {
      activeTripsAsync.whenData((trips) {
        if (trips.isNotEmpty && _selectedTripId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedTripId = trips.first.tripId;
                _selectedRouteId = trips.first.routeId;
                _selectedRouteName = trips.first.routeName;
              });
            }
          });
        }
      });
    }

    final currentTripId = _selectedTripId;
    final AsyncValue<LiveBusLocation?> locationAsync = currentTripId != null
        ? ref.watch(liveBusLocationStreamProvider(currentTripId))
        : const AsyncValue.data(null);

    final AsyncValue<List<RouteStopWithFare>> stopsAsync = _selectedRouteId != null
        ? ref.watch(routeStopsProvider(_selectedRouteId!))
        : const AsyncValue.data([]);

    // Track latest received timestamp
    locationAsync.whenData((loc) {
      if (loc != null) {
        _lastReceivedAt = loc.updatedAt;
        if (!_hasInitialCentered) {
          _hasInitialCentered = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _centerOnLocation(loc.latitude, loc.longitude);
          });
        }
      }
    });

    final busLoc = locationAsync.valueOrNull;
    final stops = stopsAsync.valueOrNull ?? [];

    // Fallback default center: Colombo University Area (6.903, 79.860) or bus location
    final initialCenter = busLoc != null
        ? LatLng(busLoc.latitude, busLoc.longitude)
        : (stops.isNotEmpty && stops.first.latitude != null && stops.first.longitude != null)
            ? LatLng(stops.first.latitude!, stops.first.longitude!)
            : const LatLng(6.927079, 79.861244);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live Bus Tracking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              _selectedRouteName ?? 'Active Campus Shuttle',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          // Trip Selector if multiple active trips exist
          activeTripsAsync.maybeWhen(
            data: (trips) {
              if (trips.length <= 1) return const SizedBox.shrink();
              return PopupMenuButton<ActiveTrip>(
                icon: const Icon(Icons.swap_horiz_rounded),
                tooltip: 'Switch Active Bus',
                onSelected: (trip) {
                  setState(() {
                    _selectedTripId = trip.tripId;
                    _selectedRouteId = trip.routeId;
                    _selectedRouteName = trip.routeName;
                    _hasInitialCentered = false;
                  });
                },
                itemBuilder: (context) => trips.map((t) {
                  return PopupMenuItem<ActiveTrip>(
                    value: t,
                    child: Text('Bus ${t.busNumber} • ${t.routeName}'),
                  );
                }).toList(),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(activeTripsProvider);
              if (currentTripId != null) {
                ref.invalidate(liveBusLocationStreamProvider(currentTripId));
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── FlutterMap with OpenStreetMap tiles ─────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 14.5,
              minZoom: 10.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.shuttle.mobile',
              ),

              // Route line if multiple stops are present
              if (stops.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: stops
                          .where((s) => s.latitude != null && s.longitude != null)
                          .map((s) => LatLng(s.latitude!, s.longitude!))
                          .toList(),
                      color: _primaryNavy.withValues(alpha: 0.6),
                      strokeWidth: 4.0,
                    ),
                  ],
                ),

              // Markers for Stops and Bus
              MarkerLayer(
                markers: [
                  // Static route stops
                  for (final stop in stops)
                    if (stop.latitude != null && stop.longitude != null)
                      Marker(
                        point: LatLng(stop.latitude!, stop.longitude!),
                        width: 90,
                        height: 60,
                        child: _StopMarker(
                          name: stop.stopName,
                          order: stop.stopOrder,
                          onTap: () => _showStopInfo(stop),
                        ),
                      ),

                  // Live updating Bus Marker
                  if (busLoc != null)
                    Marker(
                      point: LatLng(busLoc.latitude, busLoc.longitude),
                      width: 70,
                      height: 70,
                      child: _LiveBusMarker(
                        busNumber: busLoc.busNumber,
                        heading: busLoc.heading,
                        speedKmh: busLoc.speedKmh,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ── Top Status Bar: Connection & Last Updated Ticker ────────────
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: busLoc != null ? Colors.green : Colors.amber.shade700,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (busLoc != null ? Colors.green : Colors.amber).withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            busLoc != null ? 'Live Location Connected' : 'Connecting to Shuttle GPS...',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            busLoc != null
                                ? 'Last updated ${_formatTimeAgo(_lastReceivedAt)}${busLoc.speedKmh != null ? ' • ${busLoc.speedKmh!.toStringAsFixed(1)} km/h' : ''}'
                                : 'Waiting for the bus to start sharing its location',
                            style: TextStyle(
                              fontSize: 11,
                              color: busLoc != null ? Colors.grey.shade700 : Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Friendly Empty State message if no bus is active or location not yet reported ──
          if (busLoc == null)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Card(
                elevation: 6,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.departure_board_rounded, color: Colors.amber.shade800, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Waiting for Bus Location',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Waiting for the bus to start sharing its location. The map will update automatically when the driver starts moving.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Floating Action Buttons (Center on Bus / Center on Route) ──
          if (busLoc != null)
            Positioned(
              bottom: 24,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'center_bus',
                    backgroundColor: _primaryNavy,
                    tooltip: 'Center on Bus',
                    onPressed: () => _centerOnLocation(busLoc.latitude, busLoc.longitude),
                    child: const Icon(Icons.my_location_rounded, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  if (stops.isNotEmpty)
                    FloatingActionButton.small(
                      heroTag: 'center_route',
                      backgroundColor: Colors.white,
                      tooltip: 'View Route Stops',
                      onPressed: () {
                        final validStops = stops.where((s) => s.latitude != null && s.longitude != null).toList();
                        if (validStops.isNotEmpty) {
                          _centerOnLocation(validStops.first.latitude!, validStops.first.longitude!);
                        }
                      },
                      child: const Icon(Icons.alt_route_rounded, color: _primaryNavy),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showStopInfo(RouteStopWithFare stop) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _primaryNavy,
                    child: Text(
                      '${stop.stopOrder}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stop.stopName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (stop.address != null)
                          Text(stop.address!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (stop.currentFare != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Standard Fare: LKR ${stop.currentFare!.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _StopMarker extends StatelessWidget {
  const _StopMarker({
    required this.name,
    required this.order,
    required this.onTap,
  });

  final String name;
  final int order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _primaryNavy,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Center(
              child: Text(
                '$order',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBusMarker extends StatelessWidget {
  const _LiveBusMarker({
    this.busNumber,
    this.heading,
    this.speedKmh,
  });

  final String? busNumber;
  final double? heading;
  final double? speedKmh;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busNumber != null && busNumber!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _primaryNavy,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
            ),
            child: Text(
              'Bus $busNumber',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        const SizedBox(height: 2),
        Transform.rotate(
          angle: heading != null ? (heading! * (3.141592653589793 / 180)) : 0,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.amber.shade600,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.shade600.withValues(alpha: 0.6),
                  blurRadius: 10,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }
}
