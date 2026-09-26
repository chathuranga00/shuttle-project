import 'package:json_annotation/json_annotation.dart';
import 'wallet_summary.dart';

part 'student_card.g.dart';

@JsonSerializable()
class StudentCard {
  const StudentCard({
    required this.cardId,
    required this.cardStatus,
    required this.monthlyPassStatus,
    required this.wallet,
    required this.qrToken,
  });

  /// Card business identifier, e.g. "UBC-S001-1234".
  final String cardId;

  /// Card status: "ACTIVE" | "INACTIVE" | "BLOCKED" | "EXPIRED"
  final String cardStatus;

  /// Monthly pass status: "ACTIVE" | "NONE"
  final String monthlyPassStatus;

  final WalletSummary wallet;

  /// Short-lived signed JWT (60 s TTL) for QR code display. Contains no PII.
  final String qrToken;

  bool get isActive => cardStatus == 'ACTIVE';
  bool get hasActivePass => monthlyPassStatus == 'ACTIVE';

  factory StudentCard.fromJson(Map<String, dynamic> json) =>
      _$StudentCardFromJson(json);

  Map<String, dynamic> toJson() => _$StudentCardToJson(this);
}
