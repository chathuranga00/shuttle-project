import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/dio_client.dart';
import 'models/pass_status_response.dart';

class PassRepository {
  PassRepository(this._dio);

  final Dio _dio;

  Future<PassStatusResponse> getStatus() async {
    try {
      final response = await _dio.get('/api/monthly-pass/status');
      return PassStatusResponse.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException(message: ApiException.friendlyMessage(null));
    }
  }

  /// Purchase a monthly pass. [validFrom] is optional ISO date string.
  Future<PassStatusResponse> purchase({String? validFrom}) async {
    try {
      final response = await _dio.post('/api/monthly-pass/purchase',
          data: validFrom != null ? {'validFrom': validFrom} : {});
      return PassStatusResponse.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException(message: ApiException.friendlyMessage(null));
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final passRepositoryProvider = Provider<PassRepository>((ref) {
  return PassRepository(ref.watch(dioClientProvider));
});
