import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/route_list_item.dart';
import '../../data/models/route_stop_with_fare.dart';
import '../../data/route_repository.dart';

/// All available routes from GET /api/routes.
final routeListProvider = FutureProvider<List<RouteListItem>>((ref) {
  return ref.watch(routeRepositoryProvider).getRoutes();
});

/// Stops + fares for a specific route from GET /api/routes/{id}/stops.
/// Fares are loaded from the API — never hard-coded.
final routeStopsProvider =
    FutureProvider.family<List<RouteStopWithFare>, int>((ref, routeId) {
  return ref.watch(routeRepositoryProvider).getRouteStops(routeId);
});
