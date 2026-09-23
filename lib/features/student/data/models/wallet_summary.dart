import 'package:json_annotation/json_annotation.dart';

part 'wallet_summary.g.dart';

@JsonSerializable()
class WalletSummary {
  const WalletSummary({
    required this.balance,
    required this.status,
  });

  /// Raw balance as returned by the API (BigDecimal serialises as a JSON number).
  final String balance;

  /// Wallet status: "ACTIVE" | "FROZEN" | "CLOSED"
  final String status;

  factory WalletSummary.fromJson(Map<String, dynamic> json) =>
      _$WalletSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$WalletSummaryToJson(this);
}
