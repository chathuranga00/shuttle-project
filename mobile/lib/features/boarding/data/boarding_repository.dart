import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/offline/offline_cache_service.dart';
import 'models/boarding_confirm_response.dart';
import 'models/boarding_history_item.dart';
import 'models/validate_boarding_response.dart';

class BoardingRepository {
  BoardingRepository(this._dio, this._cache);

  final Dio _dio;
  final OfflineCacheService _cache;
  static const _uuid = Uuid();

  /// Validate a scanned QR payload without saving anything.
  Future<ValidateBoardingResponse> validate({
    required String stopQrPayload,
    int? tripId,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
  }) async {
    try {
      final response = await _dio.post('/api/boarding/validate', data: {
        'stopQrPayload': stopQrPayload,
        if (tripId != null) 'tripId': tripId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
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
  /// CRITICAL: Boarding confirmation ALWAYS requires live server confirmation
  /// and must NEVER be queued offline.
  Future<BoardingConfirmResponse> confirm({
    required String stopQrPayload,
    required int tripId,
    String? idempotencyKey,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
  }) async {
    final key = idempotencyKey ?? _uuid.v4();
    try {
      final response = await _dio.post('/api/boarding/confirm', data: {
        'stopQrPayload': stopQrPayload,
        'tripId': tripId,
        'idempotencyKey': key,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
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
  /// Caches locally for offline access.
  Future<List<BoardingHistoryItem>> getHistory() async {
    try {
      final response = await _dio.get('/api/boarding/history');
      final list = response.data as List<dynamic>;
      // Cache locally
      await _cache.cacheJson(OfflineCacheService.keyBoardingHistory, list);
      return list
          .map((e) => BoardingHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      // Offline fallback: check local cache
      final cached =
          await _cache.getCachedJson(OfflineCacheService.keyBoardingHistory);
      if (cached is List<dynamic> && cached.isNotEmpty) {
        return cached
            .map((e) =>
                BoardingHistoryItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException(message: ApiException.friendlyMessage(null));
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final boardingRepositoryProvider = Provider<BoardingRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  final cache = ref.watch(offlineCacheServiceProvider);
  return BoardingRepository(dio, cache);
});
