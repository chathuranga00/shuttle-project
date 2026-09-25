// GENERATED CODE - DO NOT MODIFY BY HAND
part of 'payment_history_item.dart';

PaymentHistoryItem _$PaymentHistoryItemFromJson(Map<String, dynamic> json) =>
    PaymentHistoryItem(
      id: (json['id'] as num).toInt(),
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      description: json['description'] as String?,
      createdAt: json['createdAt'] as String,
    );

Map<String, dynamic> _$PaymentHistoryItemToJson(PaymentHistoryItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'amount': instance.amount,
      'status': instance.status,
      'description': instance.description,
      'createdAt': instance.createdAt,
    };
