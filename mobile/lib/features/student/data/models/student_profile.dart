import 'package:json_annotation/json_annotation.dart';

part 'student_profile.g.dart';

@JsonSerializable()
class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    required this.studentId,
    required this.faculty,
    required this.enrollmentYear,
  });

  final int id;
  final String email;
  final String fullName;
  final String? phone;
  final String studentId;
  final String faculty;
  final int enrollmentYear;

  /// First name derived from full name (everything before the first space).
  String get firstName => fullName.split(' ').first;

  /// Initials derived from full name for avatar display (up to 2 chars).
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  factory StudentProfile.fromJson(Map<String, dynamic> json) => StudentProfile(
        id: ((json['userId'] ?? json['id'] ?? 0) as num).toInt(),
        email: (json['email'] as String?) ?? '',
        fullName: (json['fullName'] as String?) ?? '',
        phone: json['phone'] as String?,
        studentId: (json['studentId'] as String?) ?? '',
        faculty: (json['faculty'] as String?) ?? '',
        enrollmentYear: ((json['enrollmentYear'] ?? 0) as num).toInt(),
      );

  Map<String, dynamic> toJson() => _$StudentProfileToJson(this);
}
