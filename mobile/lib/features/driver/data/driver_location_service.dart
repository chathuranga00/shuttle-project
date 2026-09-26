import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'driver_repository.dart';

class DriverLocationState {
  final bool isSharing;
  final bool isPermissionDenied;
  final bool isGpsServiceDisabled;
  final DateTime? lastSentTime;
  final double? lastLatitude;
  final double? lastLongitude;
  final double? lastSpeedKmh;
  final String? statusMessage;

  const DriverLocationState({
    this.isSharing = false,
    this.isPermissionDenied = false,
    this.isGpsServiceDisabled = false,
    this.lastSentTime,
    this.lastLatitude,
    this.lastLongitude,
    this.lastSpeedKmh,
    this.statusMessage,
  });

  DriverLocationState copyWith({
    bool? isSharing,
    bool? isPermissionDenied,
    bool? isGpsServiceDisabled,
    DateTime? lastSentTime,
    double? lastLatitude,
    double? lastLongitude,
    double? lastSpeedKmh,
    String? statusMessage,
  }) {
    return DriverLocationState(
      isSharing: isSharing ?? this.isSharing,
      isPermissionDenied: isPermissionDenied ?? this.isPermissionDenied,
      isGpsServiceDisabled: isGpsServiceDisabled ?? this.isGpsServiceDisabled,
      lastSentTime: lastSentTime ?? this.lastSentTime,
      lastLatitude: lastLatitude ?? this.lastLatitude,
      lastLongitude: lastLongitude ?? this.lastLongitude,
      lastSpeedKmh: lastSpeedKmh ?? this.lastSpeedKmh,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

class DriverLocationServiceNotifier extends StateNotifier<DriverLocationState> {
  DriverLocationServiceNotifier(this._repository) : super(const DriverLocationState());

  final DriverRepository _repository;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _periodicTimer;
  int? _activeTripId;
  DateTime? _lastSentTimestamp;

  /// Starts live location tracking for the active trip.
  /// Distance filter > 10 meters and interval ~5-10s to save battery/data.
  Future<void> startTracking(int tripId) async {
    // If already tracking this exact trip, keep running
    if (state.isSharing && _activeTripId == tripId) return;

    _activeTripId = tripId;

    // Check GPS service availability
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(
        isSharing: false,
        isGpsServiceDisabled: true,
        statusMessage: 'Location services (GPS) are disabled on this device.',
      );
      return;
    }

    // Check & request location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        state = state.copyWith(
          isSharing: false,
          isPermissionDenied: true,
          statusMessage: 'Location permission denied. Students will not see this bus on the map.',
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        isSharing: false,
        isPermissionDenied: true,
        statusMessage: 'Location permission permanently denied. Enable in device Settings.',
      );
      return;
    }

    // Permission granted! Reset denial flags
    state = state.copyWith(
      isSharing: true,
      isPermissionDenied: false,
      isGpsServiceDisabled: false,
      statusMessage: 'Location sharing is active',
    );

    // Cancel any previous subscriptions
    await _positionSubscription?.cancel();
    _periodicTimer?.cancel();

    // Send an immediate position fix
    try {
      final initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _sendUpdate(initialPosition);
    } catch (e) {
      debugPrint('Error getting initial GPS position: $e');
    }

    // Listen to position changes with distance filter > 10m
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) async {
        await _sendUpdate(position);
      },
      onError: (e) {
        debugPrint('Location stream error: $e');
      },
    );

    // Also periodic heartbeat every 8 seconds if moving slowly or stationary
    _periodicTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!state.isSharing || _activeTripId == null) return;
      try {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null) {
          await _sendUpdate(pos);
        }
      } catch (e) {
        // Ignore periodic polling errors
      }
    });
  }

  Future<void> _sendUpdate(Position position) async {
    final tripId = _activeTripId;
    if (tripId == null || !state.isSharing) return;

    // Rate-limit outgoing requests to prevent 429 (at least 3.5s apart)
    final now = DateTime.now();
    if (_lastSentTimestamp != null &&
        now.difference(_lastSentTimestamp!).inMilliseconds < 3500) {
      return;
    }
    _lastSentTimestamp = now;

    final speedKmh = position.speed >= 0 ? (position.speed * 3.6) : null;

    try {
      await _repository.sendLocationUpdate(
        tripId: tripId,
        latitude: position.latitude,
        longitude: position.longitude,
        heading: position.heading >= 0 ? position.heading : null,
        speed: speedKmh,
      );

      state = state.copyWith(
        isSharing: true,
        lastSentTime: now,
        lastLatitude: position.latitude,
        lastLongitude: position.longitude,
        lastSpeedKmh: speedKmh,
        statusMessage: 'Location sharing active',
      );
    } catch (e) {
      debugPrint('Failed to send bus location update: $e');
    }
  }

  /// Stops sending updates immediately when trip ends.
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _activeTripId = null;

    state = const DriverLocationState(
      isSharing: false,
      statusMessage: 'Location sharing stopped',
    );
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}

final driverLocationServiceProvider =
    StateNotifierProvider<DriverLocationServiceNotifier, DriverLocationState>((ref) {
  final repo = ref.watch(driverRepositoryProvider);
  return DriverLocationServiceNotifier(repo);
});
