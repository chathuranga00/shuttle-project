import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/dio_client.dart';
import 'models/route_list_item.dart';
import 'models/route_stop_with_fare.dart';

class RouteRepository {
  RouteRepository(this._dio);

  final Dio _dio;

  /// Returns all active routes. Fares are never hard-coded — they come
  /// from [getRouteStops] which includes the current fare per stop.
  Future<List<RouteListItem>> getRoutes() async {
    try {
      final response = await _dio.get('/api/routes');
      final list = response.data as List<dynamic>;
      return list
          .map((e) => RouteListItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException(message: ApiException.friendlyMessage(null));
    }
  }

  /// Returns all stops for a route, each including the current active fare.
  /// [currentFare] on each stop comes from the backend — never hard-coded.
  Future<List<RouteStopWithFare>> getRouteStops(int routeId) async {
    try {
      final response = await _dio.get('/api/routes/$routeId/stops');
      final list = response.data as List<dynamic>;
      return list
          .map((e) => RouteStopWithFare.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException(message: ApiException.friendlyMessage(null));
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final routeRepositoryProvider = Provider<RouteRepository>((ref) {
  return RouteRepository(ref.watch(dioClientProvider));
});
