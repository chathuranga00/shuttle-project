import 'package:json_annotation/json_annotation.dart';

part 'pass_status_response.g.dart';

/// Maps GET /api/monthly-pass/status response.
@JsonSerializable()
class PassStatusResponse {
  const PassStatusResponse({
    this.passId,
    required this.status,
    this.validFrom,
    this.validTo,
    this.price,
    required this.coveringToday,
    required this.nextPurchasePrice,
  });

  final int?    passId;
  /// "NONE" | "PENDING" | "ACTIVE" | "EXPIRED" | "CANCELLED"
  final String  status;
  final String? validFrom;   // ISO LocalDate e.g. "2025-09-01"
  final String? validTo;
  final double? price;
  final bool    coveringToday;
  final double  nextPurchasePrice;

  bool get isActive  => status == 'ACTIVE';
  bool get isPending => status == 'PENDING';
  bool get hasPass   => status != 'NONE';

  factory PassStatusResponse.fromJson(Map<String, dynamic> json) =>
      _$PassStatusResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PassStatusResponseToJson(this);
}
