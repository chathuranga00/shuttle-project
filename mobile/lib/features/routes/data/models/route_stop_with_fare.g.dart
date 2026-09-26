// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_stop_with_fare.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RouteStopWithFare _$RouteStopWithFareFromJson(Map<String, dynamic> json) =>
    RouteStopWithFare(
      routeStopId: (json['routeStopId'] as num).toInt(),
      stopOrder: (json['stopOrder'] as num).toInt(),
      estimatedOffsetMinutes:
          (json['estimatedOffsetMinutes'] as num?)?.toInt(),
      busStopId: (json['busStopId'] as num).toInt(),
      stopName: json['stopName'] as String,
      qrCode: json['qrCode'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
      stopStatus: json['stopStatus'] as String,
      currentFare: (json['currentFare'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$RouteStopWithFareToJson(RouteStopWithFare instance) =>
    <String, dynamic>{
      'routeStopId': instance.routeStopId,
      'stopOrder': instance.stopOrder,
      'estimatedOffsetMinutes': instance.estimatedOffsetMinutes,
      'busStopId': instance.busStopId,
      'stopName': instance.stopName,
      'qrCode': instance.qrCode,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'address': instance.address,
      'stopStatus': instance.stopStatus,
      'currentFare': instance.currentFare,
    };
