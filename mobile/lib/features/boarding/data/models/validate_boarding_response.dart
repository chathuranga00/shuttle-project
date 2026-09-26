import 'package:json_annotation/json_annotation.dart';

part 'validate_boarding_response.g.dart';

/// Response from POST /api/boarding/validate.
/// [valid] is false when the QR is invalid, trip not active, etc.
@JsonSerializable()
class ValidateBoardingResponse {
  const ValidateBoardingResponse({
    required this.valid,
    required this.message,
    this.stopName,
    this.routeName,
    this.tripId,
    this.fare,
  });

  final bool    valid;
  final String  message;
  final String? stopName;
  final String? routeName;
  final int?    tripId;
  final double? fare;

  factory ValidateBoardingResponse.fromJson(Map<String, dynamic> json) =>
      _$ValidateBoardingResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ValidateBoardingResponseToJson(this);
}
