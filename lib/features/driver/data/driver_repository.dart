import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/dio_client.dart';
import 'models/card_verification_result.dart';
import 'models/driver_assignment.dart';
import 'models/driver_trip.dart';
import 'models/driver_trip_history_item.dart';
import 'models/emergency_report.dart';
import 'models/trip_summary.dart';

class DriverRepository {
  DriverRepository(this._dio);

  final Dio _dio;

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

  /// Starts the assigned trip (SCHEDULED → IN_PROGRESS).
  Future<DriverTrip> startTrip(int tripId) async {
    try {
      final response = await _dio.post('/api/trips/$tripId/start');
      return DriverTrip.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _wrapException(e);
    }
  }

  /// Ends the active trip (IN_PROGRESS → COMPLETED).
  Future<DriverTrip> endTrip(int tripId) async {
    try {
      final response = await _dio.post('/api/trips/$tripId/end');
      return DriverTrip.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _wrapException(e);
    }
  }

  /// Returns passenger counts, pass vs pay-per-trip split, and recent boardings.
  Future<TripSummary> getTripSummary(int tripId) async {
    try {
      final response = await _dio.get('/api/driver/trips/$tripId/summary');
      return TripSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _wrapException(e);
    }
  }

  /// Submits an emergency report (accident, breakdown, medical, etc.).
  Future<EmergencyReport> reportEmergency({
    required String type,
    required String description,
    String? location,
    int? tripId,
  }) async {
    try {
      final response = await _dio.post(
        '/api/driver/emergency-report',
        data: {
          'type': type,
          'description': description,
          if (location != null && location.isNotEmpty) 'location': location,
          if (tripId != null) 'tripId': tripId,
        },
      );
      return EmergencyReport.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _wrapException(e);
    }
  }

  /// Returns trip history for the driver.
  Future<List<DriverTripHistoryItem>> getTripHistory() async {
    try {
      final response = await _dio.get('/api/driver/trips/history');
      final list = (response.data as List<dynamic>? ?? [])
          .map((e) => DriverTripHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    } on DioException catch (e) {
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
  return DriverRepository(ref.watch(dioClientProvider));
});
