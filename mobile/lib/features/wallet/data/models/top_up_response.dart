import 'package:json_annotation/json_annotation.dart';

part 'top_up_response.g.dart';

@JsonSerializable()
class TopUpResponse {
  const TopUpResponse({
    required this.paymentId,
    required this.checkoutUrl,
    required this.paymentStatus,
    required this.amount,
  });

  final int    paymentId;
  final String checkoutUrl;
  final String paymentStatus;
  final double amount;

  factory TopUpResponse.fromJson(Map<String, dynamic> json) =>
      _$TopUpResponseFromJson(json);
  Map<String, dynamic> toJson() => _$TopUpResponseToJson(this);
}
