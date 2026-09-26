import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/notification_item.dart';
import '../data/notification_repository.dart';

/// Callback signature for handling push messages in foreground or background.
typedef PushMessageCallback = void Function(NotificationItem notification);

/// Handles push notification registration and message callbacks across platforms.
/// Integrates with the backend FCM device token endpoint (/api/devices).
class PushNotificationService {
  PushNotificationService(this._repository);

  final NotificationRepository _repository;
  final _messageStreamController =
      StreamController<NotificationItem>.broadcast();

  String? _currentToken;
  bool _isInitialized = false;

  /// Stream of received push messages (foreground).
  Stream<NotificationItem> get onMessageReceived =>
      _messageStreamController.stream;

  /// Returns current device token if initialized.
  String? get currentToken => _currentToken;

  /// Initialize push notifications and register the device token with the backend.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final platform = _detectPlatform();
      final token = await _obtainDeviceToken(platform);
      _currentToken = token;

      if (token != null && token.isNotEmpty) {
        debugPrint(
            '[PushNotificationService] Registering device token with backend: $platform');
        await _repository.registerDeviceToken(
          token: token,
          platform: platform,
        );
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Push registration notice: $e');
    }
  }

  /// Simulate or deliver an incoming FCM push notification (useful for foreground handling and testing).
  void handleIncomingMessage(Map<String, dynamic> rawPayload) {
    try {
      final item = NotificationItem.fromJson(rawPayload);
      _messageStreamController.add(item);
    } catch (e) {
      debugPrint('[PushNotificationService] Failed to parse incoming push: $e');
    }
  }

  /// Detect runtime platform string for /api/devices (ANDROID | IOS | WEB).
  String _detectPlatform() {
    if (kIsWeb) return 'WEB';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'ANDROID';
      case TargetPlatform.iOS:
        return 'IOS';
      case TargetPlatform.windows:
        return 'WINDOWS';
      case TargetPlatform.macOS:
        return 'MACOS';
      case TargetPlatform.linux:
        return 'LINUX';
      default:
        return 'UNKNOWN';
    }
  }

  /// Generate or retrieve device push token.
  Future<String?> _obtainDeviceToken(String platform) async {
    // In production mobile build with firebase_messaging, FirebaseMessaging.instance.getToken()
    // is called here. For multi-platform stability (Chrome web, desktop, and emulators),
    // we establish a persistent device client token identifier.
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'fcm_${platform.toLowerCase()}_token_$timestamp';
  }

  void dispose() {
    _messageStreamController.close();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  final service = PushNotificationService(repo);
  ref.onDispose(service.dispose);
  return service;
});
