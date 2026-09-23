/// Environment-aware configuration.
/// Switch [_env] or pass --dart-define=ENV=prod at build time.
enum Env { dev, prod }

class AppConfig {
  AppConfig._();

  static const Env _env = Env.dev;

  /// Android emulator reaches host machine via 10.0.2.2.
  /// For a physical device, change to your machine's LAN IP, e.g. 192.168.x.x.
  static const String _devBaseUrl = 'http://10.0.2.2:8080';
  static const String _prodBaseUrl = 'https://api.shuttle.university.lk';

  static String get baseUrl =>
      _env == Env.dev ? _devBaseUrl : _prodBaseUrl;

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
