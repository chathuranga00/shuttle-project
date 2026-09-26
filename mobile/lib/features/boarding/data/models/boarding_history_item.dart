import 'package:json_annotation/json_annotation.dart';

part 'boarding_history_item.g.dart';

/// One item from GET /api/boarding/history.
@JsonSerializable()
class BoardingHistoryItem {
  const BoardingHistoryItem({
    required this.boardingRecordId,
    required this.tripId,
    required this.routeName,
    required this.busStopName,
    this.fareAmount,
    required this.paymentStatus,
    required this.boardedAt,
  });

  final int     boardingRecordId;
  final int     tripId;
  final String  routeName;
  final String  busStopName;
  final double? fareAmount;
  final String  paymentStatus;
  final String  boardedAt; // ISO-8601 string

  bool get isPaid    => paymentStatus == 'PAID';
  bool get isUnpaid  => paymentStatus == 'UNPAID';

  factory BoardingHistoryItem.fromJson(Map<String, dynamic> json) =>
      _$BoardingHistoryItemFromJson(json);

  Map<String, dynamic> toJson() => _$BoardingHistoryItemToJson(this);
}
