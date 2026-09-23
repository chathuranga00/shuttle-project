import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/dio_client.dart';
import 'models/student_card.dart';
import 'models/student_profile.dart';

class StudentRepository {
  StudentRepository(this._dio);

  final Dio _dio;

  /// Returns the authenticated student's virtual bus card including a fresh QR token.
  Future<StudentCard> getMyCard() async {
    try {
      final response = await _dio.get('/api/students/me/card');
      return StudentCard.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException(message: ApiException.friendlyMessage(null));
    }
  }

  /// Returns the authenticated student's profile.
  Future<StudentProfile> getMyProfile() async {
    try {
      final response = await _dio.get('/api/students/me');
      return StudentProfile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException(message: ApiException.friendlyMessage(null));
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────
final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository(ref.watch(dioClientProvider));
});
