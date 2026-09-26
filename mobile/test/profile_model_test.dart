import 'package:flutter_test/flutter_test.dart';
import 'package:shuttle/features/student/data/models/student_profile.dart';

void main() {
  test('StudentProfile.fromJson parses backend payload successfully', () {
    final json = {
      "userId": 5,
      "email": "student@shuttle.dev",
      "fullName": "Demo Student",
      "phone": "+94771234567",
      "studentId": "STU-001",
      "faculty": "Computing",
      "enrollmentYear": 2024
    };

    final profile = StudentProfile.fromJson(json);
    expect(profile.id, 5);
    expect(profile.email, "student@shuttle.dev");
    expect(profile.fullName, "Demo Student");
    expect(profile.firstName, "Demo");
    expect(profile.initials, "DS");
    expect(profile.studentId, "STU-001");
    expect(profile.faculty, "Computing");
    expect(profile.enrollmentYear, 2024);
  });

  test('StudentProfile.fromJson handles Map<dynamic, dynamic>', () {
    final Map<dynamic, dynamic> dynMap = {
      "userId": 5,
      "email": "student@shuttle.dev",
      "fullName": "Demo Student",
      "phone": "+94771234567",
      "studentId": "STU-001",
      "faculty": "Computing",
      "enrollmentYear": 2024
    };

    final profile = StudentProfile.fromJson(Map<String, dynamic>.from(dynMap));
    expect(profile.firstName, "Demo");
    expect(profile.initials, "DS");
  });
}
