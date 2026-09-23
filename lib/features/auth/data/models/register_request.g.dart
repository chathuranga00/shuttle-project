// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'register_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RegisterRequest _$RegisterRequestFromJson(Map<String, dynamic> json) =>
    RegisterRequest(
      name: json['name'] as String,
      email: json['email'] as String,
      password: json['password'] as String,
      studentId: json['studentId'] as String,
      faculty: json['faculty'] as String,
      year: (json['year'] as num).toInt(),
      phone: json['phone'] as String?,
    );

Map<String, dynamic> _$RegisterRequestToJson(RegisterRequest instance) =>
    <String, dynamic>{
      'name': instance.name,
      'email': instance.email,
      'password': instance.password,
      'studentId': instance.studentId,
      'faculty': instance.faculty,
      'year': instance.year,
      'phone': instance.phone,
    };
