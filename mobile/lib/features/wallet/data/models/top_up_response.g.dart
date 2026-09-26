// GENERATED CODE - DO NOT MODIFY BY HAND
part of 'top_up_response.dart';

TopUpResponse _$TopUpResponseFromJson(Map<String, dynamic> json) => TopUpResponse(
      paymentId: (json['paymentId'] as num).toInt(),
      checkoutUrl: json['checkoutUrl'] as String,
      paymentStatus: json['paymentStatus'] as String,
      amount: (json['amount'] as num).toDouble(),
    );

Map<String, dynamic> _$TopUpResponseToJson(TopUpResponse instance) =>
    <String, dynamic>{
      'paymentId': instance.paymentId,
      'checkoutUrl': instance.checkoutUrl,
      'paymentStatus': instance.paymentStatus,
      'amount': instance.amount,
    };
