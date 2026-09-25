import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/offline/offline_cache_service.dart';
import 'models/route_list_item.dart';
import 'models/route_stop_with_fare.dart';

class RouteRepository {
  RouteRepository(this._dio, this._cache);

  final Dio _dio;
  final OfflineCacheService _cache;

  /// Returns all active routes. First attempts live network fetch and caches locally.
  /// If offline or network fails, serves cached data seamlessly.
  Future<List<RouteListItem>> getRoutes() async {
    try {
      final response = await _dio.get('/api/routes');
      final list = response.data as List<dynamic>;
      // Cache fresh data locally
      await _cache.cacheJson(OfflineCacheService.keyRoutes, list);
      return list
          .map((e) => RouteListItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      // Offline fallback: check local cache
      final cached = await _cache.getCachedJson(OfflineCacheService.keyRoutes);
      if (cached is List<dynamic> && cached.isNotEmpty) {
        return cached
            .map((e) => RouteListItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException(message: ApiException.friendlyMessage(null));
    }
  }

  /// Returns all stops for a route, each including the current active fare.
  /// First attempts live network fetch and caches per-route stops locally.
  /// If offline, serves cached stops.
  Future<List<RouteStopWithFare>> getRouteStops(int routeId) async {
    final cacheKey = '${OfflineCacheService.keyStopsPrefix}$routeId';
    try {
      final response = await _dio.get('/api/routes/$routeId/stops');
      final list = response.data as List<dynamic>;
      // Cache fresh stops locally
      await _cache.cacheJson(cacheKey, list);
      return list
          .map((e) => RouteStopWithFare.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      // Offline fallback: check local cache
      final cached = await _cache.getCachedJson(cacheKey);
      if (cached is List<dynamic> && cached.isNotEmpty) {
        return cached
            .map((e) => RouteStopWithFare.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException(message: ApiException.friendlyMessage(null));
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final routeRepositoryProvider = Provider<RouteRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  final cache = ref.watch(offlineCacheServiceProvider);
  return RouteRepository(dio, cache);
});
