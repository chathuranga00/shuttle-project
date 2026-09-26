// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StudentProfile _$StudentProfileFromJson(Map<String, dynamic> json) =>
    StudentProfile(
      id: (json['id'] as num).toInt(),
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      phone: json['phone'] as String?,
      studentId: json['studentId'] as String,
      faculty: json['faculty'] as String,
      enrollmentYear: (json['enrollmentYear'] as num).toInt(),
    );

Map<String, dynamic> _$StudentProfileToJson(StudentProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'fullName': instance.fullName,
      'phone': instance.phone,
      'studentId': instance.studentId,
      'faculty': instance.faculty,
      'enrollmentYear': instance.enrollmentYear,
    };
