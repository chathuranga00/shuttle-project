// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_list_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RouteListItem _$RouteListItemFromJson(Map<String, dynamic> json) =>
    RouteListItem(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      code: json['code'] as String,
      description: json['description'] as String?,
      estimatedDurationMinutes:
          (json['estimatedDurationMinutes'] as num?)?.toInt(),
      status: json['status'] as String,
    );

Map<String, dynamic> _$RouteListItemToJson(RouteListItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'code': instance.code,
      'description': instance.description,
      'estimatedDurationMinutes': instance.estimatedDurationMinutes,
      'status': instance.status,
    };
