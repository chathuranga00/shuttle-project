import 'package:json_annotation/json_annotation.dart';

part 'wallet_response.g.dart';

@JsonSerializable()
class WalletResponse {
  const WalletResponse({
    required this.id,
    required this.balance,
    required this.status,
  });

  final int    id;
  final double balance;
  final String status; // ACTIVE | FROZEN | CLOSED

  bool get isActive => status == 'ACTIVE';

  factory WalletResponse.fromJson(Map<String, dynamic> json) =>
      _$WalletResponseFromJson(json);
  Map<String, dynamic> toJson() => _$WalletResponseToJson(this);
}
