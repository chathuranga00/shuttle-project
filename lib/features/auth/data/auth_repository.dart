import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'models/login_request.dart';
import 'models/register_request.dart';
import 'models/token_response.dart';

class AuthRepository {
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final SecureStorageService _storage;

  Future<TokenResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post(
        '/api/auth/login',
        data: request.toJson(),
      );
      final token = TokenResponse.fromJson(
          response.data as Map<String, dynamic>);
      await _persistTokens(token);
      return token;
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException(message: ApiException.friendlyMessage(null));
    }
  }

  Future<TokenResponse> register(RegisterRequest request) async {
    try {
      final response = await _dio.post(
        '/api/auth/register',
        data: request.toJson(),
      );
      final token = TokenResponse.fromJson(
          response.data as Map<String, dynamic>);
      await _persistTokens(token);
      return token;
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException(message: ApiException.friendlyMessage(null));
    }
  }

  Future<void> logout() => _storage.clearAll();

  Future<void> _persistTokens(TokenResponse token) async {
    // Decode role from JWT payload (no library needed — just base64)
    final role = _decodeRole(token.accessToken);
    await _storage.saveAuthData(
      accessToken: token.accessToken,
      refreshToken: token.refreshToken,
      role: role,
    );
  }

  /// Extract the "role" claim from JWT payload without a JWT library.
  String _decodeRole(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return 'STUDENT';
      // Base64url decode the payload
      var payload = parts[1];
      // Pad to multiple of 4
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = String.fromCharCodes(
        Uri.decodeFull(payload
                .replaceAll('-', '+')
                .replaceAll('_', '/'))
            .codeUnits,
      );
      // Simple regex extraction — avoids dart:convert dependency chain
      final match = RegExp(r'"role"\s*:\s*"([^"]+)"').firstMatch(decoded);
      return match?.group(1) ?? 'STUDENT';
    } catch (_) {
      return 'STUDENT';
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(dioClientProvider),
    ref.watch(secureStorageServiceProvider),
  );
});
