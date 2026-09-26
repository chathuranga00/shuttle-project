import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../storage/secure_storage_service.dart';
import 'auth_interceptor.dart';
import 'session_expired_notifier.dart';

// ── Provider ─────────────────────────────────────────────────────────────────
/// Provide the Dio instance. The [onSessionExpired] callback notifies
/// [sessionExpiredNotifierProvider] so the auth state resets and router redirects.
final dioClientProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(
      storage: storage,
      onSessionExpired: () {
        ref.read(sessionExpiredNotifierProvider.notifier).trigger();
      },
    ),
    LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (o) => _log(o.toString()),
    ),
  ]);

  return dio;
});

void _log(String message) {
  // ignore: avoid_print
  assert(() {
    // ignore: avoid_print
    print('[DioClient] $message');
    return true;
  }());
}
