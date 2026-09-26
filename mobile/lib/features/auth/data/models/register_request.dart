import 'package:json_annotation/json_annotation.dart';

part 'register_request.g.dart';

@JsonSerializable()
class RegisterRequest {
  const RegisterRequest({
    required this.name,
    required this.email,
    required this.password,
    required this.studentId,
    required this.faculty,
    required this.year,
    this.phone,
  });

  final String name;
  final String email;
  final String password;
  final String studentId;
  final String faculty;
  final int year;
  final String? phone;

  Map<String, dynamic> toJson() => _$RegisterRequestToJson(this);
}
