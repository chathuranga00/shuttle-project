// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'validate_boarding_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ValidateBoardingResponse _$ValidateBoardingResponseFromJson(
        Map<String, dynamic> json) =>
    ValidateBoardingResponse(
      valid: json['valid'] as bool,
      message: json['message'] as String,
      stopName: json['stopName'] as String?,
      routeName: json['routeName'] as String?,
      tripId: (json['tripId'] as num?)?.toInt(),
      fare: (json['fare'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$ValidateBoardingResponseToJson(
        ValidateBoardingResponse instance) =>
    <String, dynamic>{
      'valid': instance.valid,
      'message': instance.message,
      'stopName': instance.stopName,
      'routeName': instance.routeName,
      'tripId': instance.tripId,
      'fare': instance.fare,
    };
