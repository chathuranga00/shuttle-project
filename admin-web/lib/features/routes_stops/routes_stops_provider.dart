import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

class RouteStopItem {
  final int id;
  final int stopId;
  final String stopName;
  final String? stopCode;
  final int stopOrder;
  final int? estimatedOffsetMinutes;

  const RouteStopItem({
    required this.id,
    required this.stopId,
    required this.stopName,
    this.stopCode,
    required this.stopOrder,
    this.estimatedOffsetMinutes,
  });

  factory RouteStopItem.fromJson(Map<String, dynamic> json) {
    return RouteStopItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      stopId: (json['busStopId'] ?? json['stopId'] as num?)?.toInt() ?? 0,
      stopName: json['stopName'] as String? ?? 'Stop',
      stopCode: json['stopCode'] as String?,
      stopOrder: (json['stopOrder'] as num?)?.toInt() ?? 1,
      estimatedOffsetMinutes: (json['estimatedOffsetMinutes'] as num?)?.toInt(),
    );
  }
}

class RouteItem {
  final int id;
  final String name;
  final String code;
  final String? description;
  final int? estimatedDurationMinutes;
  final String status;
  final List<RouteStopItem> stops;

  const RouteItem({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.estimatedDurationMinutes,
    required this.status,
    required this.stops,
  });

  factory RouteItem.fromJson(Map<String, dynamic> json) {
    final rawStops = json['stops'] as List? ?? [];
    final stopsList = rawStops
        .map((s) => RouteStopItem.fromJson(s as Map<String, dynamic>))
        .toList();
    stopsList.sort((a, b) => a.stopOrder.compareTo(b.stopOrder));

    return RouteItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      description: json['description'] as String?,
      estimatedDurationMinutes: (json['estimatedDurationMinutes'] as num?)?.toInt(),
      status: json['status'] as String? ?? 'ACTIVE',
      stops: stopsList,
    );
  }
}

class StopItem {
  final int id;
  final String name;
  final String qrCode;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String status;

  const StopItem({
    required this.id,
    required this.name,
    required this.qrCode,
    this.latitude,
    this.longitude,
    this.address,
    required this.status,
  });

  factory StopItem.fromJson(Map<String, dynamic> json) {
    return StopItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      qrCode: json['qrCode'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
    );
  }
}

class FareItem {
  final int id;
  final int routeId;
  final String? routeName;
  final int stopId;
  final String? stopName;
  final String fareClass;
  final double amount;
  final String effectiveFrom;
  final String? effectiveUntil;

  const FareItem({
    required this.id,
    required this.routeId,
    this.routeName,
    required this.stopId,
    this.stopName,
    required this.fareClass,
    required this.amount,
    required this.effectiveFrom,
    this.effectiveUntil,
  });

  factory FareItem.fromJson(Map<String, dynamic> json) {
    return FareItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      routeId: (json['routeId'] as num?)?.toInt() ?? 0,
      routeName: json['routeName'] as String?,
      stopId: (json['stopId'] as num?)?.toInt() ?? 0,
      stopName: json['stopName'] as String?,
      fareClass: json['fareClass'] as String? ?? 'STANDARD',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      effectiveFrom: json['effectiveFrom'] as String? ?? '',
      effectiveUntil: json['effectiveUntil'] as String?,
    );
  }
}

final routesProvider = FutureProvider.autoDispose<List<RouteItem>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get(ApiEndpoints.routes);
  final list = response.data as List? ?? [];
  return list.map((item) => RouteItem.fromJson(item as Map<String, dynamic>)).toList();
});

final stopsProvider = FutureProvider.autoDispose<List<StopItem>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get(ApiEndpoints.stops);
  final list = response.data as List? ?? [];
  return list.map((item) => StopItem.fromJson(item as Map<String, dynamic>)).toList();
});

final faresProvider = FutureProvider.autoDispose.family<List<FareItem>, int?>((ref, routeId) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get(
    ApiEndpoints.fares,
    queryParameters: routeId != null ? {'routeId': routeId} : null,
  );
  final list = response.data as List? ?? [];
  return list.map((item) => FareItem.fromJson(item as Map<String, dynamic>)).toList();
});
