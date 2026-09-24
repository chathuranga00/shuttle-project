import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/dio_client.dart';
import 'models/boarding_confirm_response.dart';
import 'models/boarding_history_item.dart';
import 'models/validate_boarding_response.dart';

class BoardingRepository {
  BoardingRepository(this._dio);

  final Dio _dio;
  static const _uuid = Uuid();

  /// Validate a scanned QR payload without saving anything.
  Future<ValidateBoardingResponse> validate({
    required String stopQrPayload,
    int? tripId,
  }) async {
    try {
      final response = await _dio.post('/api/boarding/validate', data: {
        'stopQrPayload': stopQrPayload,
        if (tripId != null) 'tripId': tripId,
      });
      return ValidateBoardingResponse.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException(message: ApiException.friendlyMessage(null));
    }
  }

  /// Confirm a boarding. Generates a UUID idempotency key so retries are safe.
  /// Returns a [BoardingConfirmResponse] only if the server confirms success.
  Future<BoardingConfirmResponse> confirm({
    required String stopQrPayload,
    required int tripId,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? _uuid.v4();
    try {
      final response = await _dio.post('/api/boarding/confirm', data: {
        'stopQrPayload': stopQrPayload,
        'tripId': tripId,
        'idempotencyKey': key,
      });
      return BoardingConfirmResponse.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException(message: ApiException.friendlyMessage(null));
    }
  }

  /// Boarding history for the authenticated student, most recent first.
  Future<List<BoardingHistoryItem>> getHistory() async {
    try {
      final response = await _dio.get('/api/boarding/history');
      final list = response.data as List<dynamic>;
      return list
          .map((e) => BoardingHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException(message: ApiException.friendlyMessage(null));
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final boardingRepositoryProvider = Provider<BoardingRepository>((ref) {
  return BoardingRepository(ref.watch(dioClientProvider));
});
