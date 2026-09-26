// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pass_status_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PassStatusResponse _$PassStatusResponseFromJson(Map<String, dynamic> json) =>
    PassStatusResponse(
      passId: (json['passId'] as num?)?.toInt(),
      status: json['status'] as String,
      validFrom: json['validFrom'] as String?,
      validTo: json['validTo'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      coveringToday: json['coveringToday'] as bool,
      nextPurchasePrice: (json['nextPurchasePrice'] as num).toDouble(),
    );

Map<String, dynamic> _$PassStatusResponseToJson(
        PassStatusResponse instance) =>
    <String, dynamic>{
      'passId': instance.passId,
      'status': instance.status,
      'validFrom': instance.validFrom,
      'validTo': instance.validTo,
      'price': instance.price,
      'coveringToday': instance.coveringToday,
      'nextPurchasePrice': instance.nextPurchasePrice,
    };
