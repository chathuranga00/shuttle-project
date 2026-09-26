import 'package:json_annotation/json_annotation.dart';

part 'payment_history_item.g.dart';

@JsonSerializable()
class PaymentHistoryItem {
  const PaymentHistoryItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.status,
    this.description,
    required this.createdAt,
  });

  final int     id;
  final String  type;
  final double  amount;
  final String  status;
  final String? description;
  final String  createdAt;

  bool get isSuccess => status == 'SUCCESS';

  factory PaymentHistoryItem.fromJson(Map<String, dynamic> json) =>
      _$PaymentHistoryItemFromJson(json);
  Map<String, dynamic> toJson() => _$PaymentHistoryItemToJson(this);
}
