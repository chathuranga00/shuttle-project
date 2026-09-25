import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/offline/offline_action_queue_service.dart';
import '../../../core/offline/offline_cache_service.dart';
import 'models/notification_item.dart';

class NotificationRepository {
  NotificationRepository(this._dio, this._cache, this._queue);

  final Dio _dio;
  final OfflineCacheService _cache;
  final OfflineActionQueueService _queue;

  /// Fetch notifications for the current user.
  /// Caches result locally; falls back to cache if offline.
  Future<List<NotificationItem>> getNotifications({
    int page = 0,
    int size = 30,
    bool? unreadOnly,
  }) async {
    try {
      final response = await _dio.get(
        '/api/notifications',
        queryParameters: {
          'page': page,
          'size': size,
          if (unreadOnly != null) 'unreadOnly': unreadOnly,
        },
      );

      final list = response.data as List<dynamic>;
      // Cache fresh data locally
      await _cache.cacheJson(OfflineCacheService.keyNotifications, list);

      return list
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      // Offline fallback: load cached notifications
      final cached =
          await _cache.getCachedJson(OfflineCacheService.keyNotifications);
      if (cached is List<dynamic> && cached.isNotEmpty) {
        var items = cached
            .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
            .toList();
        if (unreadOnly == true) {
          items = items.where((n) => !n.isRead).toList();
        }
        return items;
      }
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException(message: ApiException.friendlyMessage(null));
    }
  }

  /// Get the current unread notifications count.
  Future<int> getUnreadCount() async {
    try {
      final response = await _dio.get('/api/notifications/unread-count');
      final count = (response.data['unreadCount'] as num).toInt();
      await _cache.save(OfflineCacheService.keyUnreadCount, count.toString());
      return count;
    } on DioException catch (_) {
      final cached = await _cache.get(OfflineCacheService.keyUnreadCount);
      if (cached != null) {
        return int.tryParse(cached) ?? 0;
      }
      return 0;
    }
  }

  /// Mark a single notification as read.
  /// If offline, queues the safe action and applies optimistic update to cache.
  Future<void> markAsRead(int notificationId) async {
    final endpoint = '/api/notifications/$notificationId/read';
    try {
      await _dio.patch(endpoint);
    } on DioException catch (_) {
      // Safe non-payment action: queue offline with idempotency key
      await _queue.enqueueAction(
        endpoint: endpoint,
        method: 'PATCH',
      );
    }

    // Optimistically update local cache
    await _markLocalAsRead(notificationId);
  }

  /// Mark all notifications as read.
  /// If offline, queues the safe action and updates local cache.
  Future<void> markAllAsRead() async {
    const endpoint = '/api/notifications/read-all';
    try {
      await _dio.patch(endpoint);
    } on DioException catch (_) {
      // Safe non-payment action: queue offline
      await _queue.enqueueAction(
        endpoint: endpoint,
        method: 'PATCH',
      );
    }

    // Optimistically update local cache
    await _markAllLocalAsRead();
  }

  /// Register FCM device token with the backend.
  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    const endpoint = '/api/devices';
    final payload = {
      'token': token,
      'platform': platform.toUpperCase(),
    };

    try {
      await _dio.post(endpoint, data: payload);
    } on DioException catch (_) {
      // Queue offline if disconnected
      await _queue.enqueueAction(
        endpoint: endpoint,
        method: 'POST',
        payload: payload,
      );
    }
  }

  Future<void> _markLocalAsRead(int id) async {
    final cached =
        await _cache.getCachedJson(OfflineCacheService.keyNotifications);
    if (cached is List<dynamic>) {
      final updated = cached.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        if (map['id'] == id) {
          map['isRead'] = true;
          map['readAt'] = DateTime.now().toIso8601String();
        }
        return map;
      }).toList();
      await _cache.cacheJson(OfflineCacheService.keyNotifications, updated);
    }
  }

  Future<void> _markAllLocalAsRead() async {
    final cached =
        await _cache.getCachedJson(OfflineCacheService.keyNotifications);
    if (cached is List<dynamic>) {
      final updated = cached.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        map['isRead'] = true;
        map['readAt'] ??= DateTime.now().toIso8601String();
        return map;
      }).toList();
      await _cache.cacheJson(OfflineCacheService.keyNotifications, updated);
      await _cache.save(OfflineCacheService.keyUnreadCount, '0');
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  final cache = ref.watch(offlineCacheServiceProvider);
  final queue = ref.watch(offlineActionQueueServiceProvider);
  return NotificationRepository(dio, cache, queue);
});
