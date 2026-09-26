import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/offline/offline_action_queue_service.dart';
import '../../../core/offline/offline_cache_service.dart';
import 'models/card_verification_result.dart';
import 'models/driver_assignment.dart';
import 'models/driver_trip.dart';
import 'models/driver_trip_history_item.dart';
import 'models/emergency_report.dart';
import 'models/trip_summary.dart';

class DriverRepository {
  DriverRepository(this._dio, this._cache, this._queue);

  final Dio _dio;
  final OfflineCacheService _cache;
  final OfflineActionQueueService _queue;

  static const String _keyTripHistory = 'cache_driver_trip_history';

  /// Fetches the driver's current assigned trip for today (active or next scheduled).
  /// Returns null if no trip is assigned for today.
  Future<DriverTrip?> getCurrentTrip() async {
    try {
      final response = await _dio.get('/api/trips/current');
      if (response.data == null) return null;
      return DriverTrip.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw _wrapException(e);
    }
  }

  /// Starts a scheduled trip: POST /api/trips/{id}/start.
  Future<void> startTrip(int tripId) async {
    try {
      await _dio.post('/api/trips/$tripId/start');
    } on DioException catch (e) {
      throw _wrapException(e);
    }
  }

  /// Ends an in-progress trip: POST /api/trips/{id}/end.
  Future<void> endTrip(int tripId) async {
    try {
      await _dio.post('/api/trips/$tripId/end');
    } on DioException catch (e) {
      throw _wrapException(e);
    }
  }

  /// Returns real-time passenger counts and monthly vs pay-per-trip split.
  Future<TripSummary> getTripSummary(int tripId) async {
    try {
      final response = await _dio.get('/api/driver/trips/$tripId/summary');
      return TripSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _wrapException(e);
    }
  }

  /// Submits an emergency report (accident, breakdown, medical, etc.).
  /// If offline, queues the safe action to sync with idempotency key upon reconnection.
  Future<EmergencyReport> reportEmergency({
    required String type,
    required String description,
    String? location,
    int? tripId,
  }) async {
    final payload = {
      'type': type,
      'description': description,
      if (location != null && location.isNotEmpty) 'location': location,
      if (tripId != null) 'tripId': tripId,
    };

    try {
      final response = await _dio.post(
        '/api/driver/emergency-report',
        data: payload,
      );
      return EmergencyReport.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        // Safe non-payment action: queue offline
        await _queue.enqueueAction(
          endpoint: '/api/driver/emergency-report',
          method: 'POST',
          payload: payload,
        );
        return EmergencyReport(
          id: -1,
          driverId: 0,
          driverName: 'Driver',
          tripId: tripId,
          type: type,
          description: description,
          location: location,
          status: 'QUEUED_OFFLINE',
          createdAt: DateTime.now(),
        );
      }
      throw _wrapException(e);
    }
  }

  /// Returns trip history for the driver with offline cache fallback.
  Future<List<DriverTripHistoryItem>> getTripHistory() async {
    try {
      final response = await _dio.get('/api/driver/trips/history');
      final list = (response.data as List<dynamic>? ?? []);
      // Cache locally
      await _cache.cacheJson(_keyTripHistory, list);
      return list
          .map((e) => DriverTripHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      // Offline fallback: load from cache
      final cached = await _cache.getCachedJson(_keyTripHistory);
      if (cached is List<dynamic> && cached.isNotEmpty) {
        return cached
            .map((e) =>
                DriverTripHistoryItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw _wrapException(e);
    }
  }

  /// Returns currently assigned bus and route with stops.
  Future<DriverAssignment> getAssignment() async {
    try {
      final response = await _dio.get('/api/driver/assignment');
      return DriverAssignment.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _wrapException(e);
    }
  }

  /// Manually verifies a student's virtual bus card QR token.
  /// CRITICAL: Verification requires live server confirmation.
  Future<CardVerificationResult> verifyCard(String qrToken) async {
    try {
      final response = await _dio.post(
        '/api/cards/verify',
        data: {'qrToken': qrToken},
      );
      return CardVerificationResult.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _wrapException(e);
    }
  }

  /// POST /api/driver/trips/{tripId}/location
  /// Sends current GPS location of the bus for an active trip.
  Future<void> sendLocationUpdate({
    required int tripId,
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
  }) async {
    try {
      await _dio.post(
        '/api/driver/trips/$tripId/location',
        data: {
          'latitude': latitude,
          'longitude': longitude,
          if (heading != null) 'heading': heading,
          if (speed != null) 'speed': speed,
        },
      );
    } on DioException catch (e) {
      // 429 Too Many Requests rate-limiting is safe to suppress for streaming GPS updates
      if (e.response?.statusCode != 429) {
        throw _wrapException(e);
      }
    }
  }

  ApiException _wrapException(DioException e) {
    if (e.error is ApiException) {
      return e.error as ApiException;
    }
    final message = (e.response?.data is Map)
        ? (e.response!.data['message'] as String? ?? 'An error occurred')
        : 'An error occurred';
    final code = (e.response?.data is Map)
        ? (e.response!.data['code'] as String?)
        : null;
    return ApiException(
      message: message,
      code: code,
      statusCode: e.response?.statusCode,
    );
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────
final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  final cache = ref.watch(offlineCacheServiceProvider);
  final queue = ref.watch(offlineActionQueueServiceProvider);
  return DriverRepository(dio, cache, queue);
});
