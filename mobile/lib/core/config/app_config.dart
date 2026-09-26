import 'package:flutter/foundation.dart';

/// Environment-aware configuration.
/// Switch via compile-time variables:
///   --dart-define=ENV=prod
///   --dart-define=API_BASE_URL=https://api.shuttle.university.lk
enum Env { dev, prod }

class AppConfig {
  AppConfig._();

  static const String _envString = String.fromEnvironment('ENV', defaultValue: 'dev');
  static Env get env => _envString.toLowerCase() == 'prod' ? Env.prod : Env.dev;

  /// Android emulator reaches host machine via 10.0.2.2.
  /// Web / Chrome / Desktop reaches host machine via localhost.
  /// For a physical device, pass --dart-define=API_BASE_URL=http://<YOUR_LAN_IP>:8080.
  static String get _devBaseUrl =>
      kIsWeb ? 'http://localhost:8080' : 'http://10.0.2.2:8080';
  static const String _prodBaseUrl = 'https://api.shuttle.university.lk';

  static const String _customBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get baseUrl {
    if (_customBaseUrl.isNotEmpty) return _customBaseUrl;
    return env == Env.dev ? _devBaseUrl : _prodBaseUrl;
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
