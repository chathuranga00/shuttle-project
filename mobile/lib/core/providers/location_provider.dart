import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Describes the outcome of a location request.
sealed class LocationResult {}

class LocationAvailable extends LocationResult {
  LocationAvailable(this.position);
  final Position position;
}

class LocationPermissionDenied extends LocationResult {
  LocationPermissionDenied(this.permanent);
  /// true when the user chose "Never Ask Again" on Android or denied twice on iOS.
  final bool permanent;
}

class LocationServiceDisabled extends LocationResult {}

class LocationError extends LocationResult {
  LocationError(this.message);
  final String message;
}

/// Requests location permission (with explanation if needed) and returns the
/// current position, or a typed error describing why it is unavailable.
///
/// This is a plain async function — call it from a ConsumerState rather than
/// watching it as a provider, since each call triggers a fresh permission flow.
Future<LocationResult> requestLocation() async {
  // 1. Check if location services are enabled
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return LocationServiceDisabled();
  }

  // 2. Check / request permission
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return LocationPermissionDenied(false);
    }
  }
  if (permission == LocationPermission.deniedForever) {
    return LocationPermissionDenied(true);
  }

  // 3. Get current position
  try {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return LocationAvailable(position);
  } on TimeoutException {
    // Fallback to last known if high-accuracy times out
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return LocationAvailable(last);
    return LocationError(
        'Could not get your location. Please try again in an open area.');
  } catch (e) {
    return LocationError('Location error: $e');
  }
}

/// Opens the app-level settings page so the user can grant location permission.
Future<void> openLocationSettings() => Geolocator.openAppSettings();

/// Opens the device location settings (to enable GPS).
Future<void> openDeviceLocationSettings() =>
    Geolocator.openLocationSettings();
