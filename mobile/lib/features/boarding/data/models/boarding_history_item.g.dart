// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'boarding_history_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BoardingHistoryItem _$BoardingHistoryItemFromJson(Map<String, dynamic> json) =>
    BoardingHistoryItem(
      boardingRecordId: (json['boardingRecordId'] as num).toInt(),
      tripId: (json['tripId'] as num).toInt(),
      routeName: json['routeName'] as String,
      busStopName: json['busStopName'] as String,
      fareAmount: (json['fareAmount'] as num?)?.toDouble(),
      paymentStatus: json['paymentStatus'] as String,
      boardedAt: json['boardedAt'] as String,
    );

Map<String, dynamic> _$BoardingHistoryItemToJson(
        BoardingHistoryItem instance) =>
    <String, dynamic>{
      'boardingRecordId': instance.boardingRecordId,
      'tripId': instance.tripId,
      'routeName': instance.routeName,
      'busStopName': instance.busStopName,
      'fareAmount': instance.fareAmount,
      'paymentStatus': instance.paymentStatus,
      'boardedAt': instance.boardedAt,
    };
