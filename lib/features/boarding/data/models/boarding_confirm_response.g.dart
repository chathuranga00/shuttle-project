// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'boarding_confirm_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BoardingConfirmResponse _$BoardingConfirmResponseFromJson(
        Map<String, dynamic> json) =>
    BoardingConfirmResponse(
      boardingRecordId: (json['boardingRecordId'] as num).toInt(),
      tripId: (json['tripId'] as num).toInt(),
      routeName: json['routeName'] as String,
      stopName: json['stopName'] as String,
      fareAmount: (json['fareAmount'] as num?)?.toDouble(),
      paymentStatus: json['paymentStatus'] as String,
      boardedAt: json['boardedAt'] as String,
      alreadyBoarded: json['alreadyBoarded'] as bool,
    );

Map<String, dynamic> _$BoardingConfirmResponseToJson(
        BoardingConfirmResponse instance) =>
    <String, dynamic>{
      'boardingRecordId': instance.boardingRecordId,
      'tripId': instance.tripId,
      'routeName': instance.routeName,
      'stopName': instance.stopName,
      'fareAmount': instance.fareAmount,
      'paymentStatus': instance.paymentStatus,
      'boardedAt': instance.boardedAt,
      'alreadyBoarded': instance.alreadyBoarded,
    };
