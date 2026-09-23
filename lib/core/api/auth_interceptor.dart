import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../storage/secure_storage_service.dart';
import 'api_exception.dart';

/// Attaches the Bearer access token to every request.
/// On 401, attempts a silent refresh and retries the original request once.
/// If the refresh also fails, clears storage so the app redirects to login.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.storage,
    required this.onSessionExpired,
  });

  final SecureStorageService storage;
  /// Called when refresh fails — router should navigate to /login.
  final void Function() onSessionExpired;

  // Prevents multiple simultaneous refresh calls.
  bool _isRefreshing = false;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await storage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Only intercept 401 and skip the refresh endpoint itself
    if (err.response?.statusCode == 401 &&
        !(err.requestOptions.path.contains('/auth/refresh')) &&
        !_isRefreshing) {
      _isRefreshing = true;
      try {
        final newAccessToken = await _refreshToken(err.requestOptions.baseUrl);
        if (newAccessToken != null) {
          // Retry original request with fresh token
          final opts = err.requestOptions
            ..headers['Authorization'] = 'Bearer $newAccessToken';
          final cloned = await err.requestOptions.copyWith(
            headers: opts.headers,
          ).let((o) async {
            return Dio().fetch(o);
          });
          handler.resolve(cloned);
          return;
        }
      } catch (_) {
        // Refresh itself failed
      } finally {
        _isRefreshing = false;
      }
      await storage.clearAll();
      onSessionExpired();
    }

    // Transform DioException → ApiException with a user-friendly message
    handler.next(_toDioException(err));
  }

  Future<String?> _refreshToken(String baseUrl) async {
    final refreshToken = await storage.getRefreshToken();
    if (refreshToken == null) return null;

    final dio = Dio(BaseOptions(baseUrl: AppConfig.baseUrl));
    final response = await dio.post(
      '/api/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    final newAccess = response.data['accessToken'] as String;
    final newRefresh = response.data['refreshToken'] as String;
    await storage.saveAccessToken(newAccess);
    await storage.saveRefreshToken(newRefresh);
    return newAccess;
  }

  DioException _toDioException(DioException err) {
    final data = err.response?.data;
    String message = 'Something went wrong. Please try again.';
    String? code;
    final statusCode = err.response?.statusCode;

    if (data is Map) {
      message = (data['message'] as String?) ?? message;
      code = data['code'] as String?;
    } else if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timed out. Check your network and try again.';
    } else if (err.type == DioExceptionType.connectionError) {
      message = 'Cannot reach the server. Check your network connection.';
    }

    return err.copyWith(
      error: ApiException(
        message: message,
        code: code,
        statusCode: statusCode,
      ),
    );
  }
}

// Tiny helper to avoid a separate package
extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
