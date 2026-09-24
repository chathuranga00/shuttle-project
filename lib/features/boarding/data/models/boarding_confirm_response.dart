import 'package:json_annotation/json_annotation.dart';

part 'boarding_confirm_response.g.dart';

/// Response from POST /api/boarding/confirm.
@JsonSerializable()
class BoardingConfirmResponse {
  const BoardingConfirmResponse({
    required this.boardingRecordId,
    required this.tripId,
    required this.routeName,
    required this.stopName,
    this.fareAmount,
    required this.paymentStatus,
    required this.boardedAt,
    required this.alreadyBoarded,
  });

  final int     boardingRecordId;
  final int     tripId;
  final String  routeName;
  final String  stopName;
  final double? fareAmount;
  /// "UNPAID" initially; will become "PAID" after payment.
  final String  paymentStatus;
  final String  boardedAt;   // ISO-8601 string
  /// true if this is an idempotent replay (server already had this record)
  final bool    alreadyBoarded;

  bool get isUnpaid => paymentStatus == 'UNPAID';

  factory BoardingConfirmResponse.fromJson(Map<String, dynamic> json) =>
      _$BoardingConfirmResponseFromJson(json);

  Map<String, dynamic> toJson() => _$BoardingConfirmResponseToJson(this);
}
