// GENERATED CODE - DO NOT MODIFY BY HAND
part of 'payment_status_response.dart';

PaymentStatusResponse _$PaymentStatusResponseFromJson(
        Map<String, dynamic> json) =>
    PaymentStatusResponse(
      paymentId: (json['paymentId'] as num).toInt(),
      status: json['status'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: json['type'] as String,
    );

Map<String, dynamic> _$PaymentStatusResponseToJson(
        PaymentStatusResponse instance) =>
    <String, dynamic>{
      'paymentId': instance.paymentId,
      'status': instance.status,
      'amount': instance.amount,
      'type': instance.type,
    };
