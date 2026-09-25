// GENERATED CODE - DO NOT MODIFY BY HAND
part of 'transaction_item.dart';

TransactionItem _$TransactionItemFromJson(Map<String, dynamic> json) =>
    TransactionItem(
      id: (json['id'] as num).toInt(),
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      balanceAfter: (json['balanceAfter'] as num).toDouble(),
      description: json['description'] as String?,
      createdAt: json['createdAt'] as String,
    );

Map<String, dynamic> _$TransactionItemToJson(TransactionItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'amount': instance.amount,
      'balanceAfter': instance.balanceAfter,
      'description': instance.description,
      'createdAt': instance.createdAt,
    };
