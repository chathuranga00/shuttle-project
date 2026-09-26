import 'package:json_annotation/json_annotation.dart';

part 'payment_status_response.g.dart';

@JsonSerializable()
class PaymentStatusResponse {
  const PaymentStatusResponse({
    required this.paymentId,
    required this.status,
    required this.amount,
    required this.type,
  });

  final int    paymentId;
  final String status;  // PENDING | SUCCESS | FAILED | CANCELLED
  final double amount;
  final String type;

  bool get isSuccess => status == 'SUCCESS';
  bool get isPending => status == 'PENDING';

  factory PaymentStatusResponse.fromJson(Map<String, dynamic> json) =>
      _$PaymentStatusResponseFromJson(json);
  Map<String, dynamic> toJson() => _$PaymentStatusResponseToJson(this);
}
