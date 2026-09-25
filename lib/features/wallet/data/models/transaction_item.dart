import 'package:json_annotation/json_annotation.dart';

part 'transaction_item.g.dart';

@JsonSerializable()
class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.description,
    required this.createdAt,
  });

  final int     id;
  final String  type;        // CREDIT | DEBIT
  final double  amount;
  final double  balanceAfter;
  final String? description;
  final String  createdAt;   // ISO-8601

  bool get isCredit => type == 'CREDIT';

  factory TransactionItem.fromJson(Map<String, dynamic> json) =>
      _$TransactionItemFromJson(json);
  Map<String, dynamic> toJson() => _$TransactionItemToJson(this);
}
