import 'package:json_annotation/json_annotation.dart';

part 'route_stop_with_fare.g.dart';

/// A route stop enriched with the current active fare.
/// Returned by GET /api/routes/{id}/stops.
/// [currentFare] is null when no active fare is configured for this stop.
@JsonSerializable()
class RouteStopWithFare {
  const RouteStopWithFare({
    required this.routeStopId,
    required this.stopOrder,
    this.estimatedOffsetMinutes,
    required this.busStopId,
    required this.stopName,
    required this.qrCode,
    this.latitude,
    this.longitude,
    this.address,
    required this.stopStatus,
    this.currentFare,
  });

  final int    routeStopId;
  final int    stopOrder;
  final int?   estimatedOffsetMinutes;
  final int    busStopId;
  final String stopName;
  final String qrCode;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String  stopStatus;

  /// Current active STANDARD fare amount in LKR.
  /// Null means no fare is configured — never hard-code a fallback.
  final double? currentFare;

  bool get hasFare => currentFare != null;

  factory RouteStopWithFare.fromJson(Map<String, dynamic> json) =>
      _$RouteStopWithFareFromJson(json);

  Map<String, dynamic> toJson() => _$RouteStopWithFareToJson(this);
}
