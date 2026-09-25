import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service responsible for persisting and retrieving read-only data
/// (routes, stops, history, notifications) for offline availability.
class OfflineCacheService {
  OfflineCacheService(this._storage);

  final FlutterSecureStorage _storage;
  final Map<String, dynamic> _memoryCache = {};

  static const String keyRoutes = 'cache_routes';
  static const String keyStopsPrefix = 'cache_stops_';
  static const String keyBoardingHistory = 'cache_boarding_history';
  static const String keyNotifications = 'cache_notifications';
  static const String keyUnreadCount = 'cache_unread_count';

  /// Save raw string value to both memory and secure disk cache.
  Future<void> save(String key, String value) async {
    _memoryCache[key] = value;
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // Memory cache is still available as fallback
    }
  }

  /// Get raw string value from memory first, falling back to secure disk cache.
  Future<String?> get(String key) async {
    if (_memoryCache.containsKey(key)) {
      final memVal = _memoryCache[key];
      return memVal is String ? memVal : jsonEncode(memVal);
    }
    try {
      final diskVal = await _storage.read(key: key);
      if (diskVal != null) {
        _memoryCache[key] = diskVal;
      }
      return diskVal;
    } catch (_) {
      return null;
    }
  }

  /// Cache an arbitrary JSON encodable object (List or Map).
  Future<void> cacheJson(String key, dynamic data) async {
    _memoryCache[key] = data;
    try {
      final jsonString = jsonEncode(data);
      await _storage.write(key: key, value: jsonString);
    } catch (_) {}
  }

  /// Retrieve cached JSON decoded data (List or Map).
  Future<dynamic> getCachedJson(String key) async {
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }
    try {
      final diskVal = await _storage.read(key: key);
      if (diskVal != null && diskVal.isNotEmpty) {
        final decoded = jsonDecode(diskVal);
        _memoryCache[key] = decoded;
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  /// Remove a specific cache entry.
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  /// Clear all cache entries.
  Future<void> clearAll() async {
    _memoryCache.clear();
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────
final offlineCacheServiceProvider = Provider<OfflineCacheService>((ref) {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  return OfflineCacheService(storage);
});
