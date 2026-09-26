import 'package:json_annotation/json_annotation.dart';

part 'route_list_item.g.dart';

/// Lightweight route summary returned by GET /api/routes.
@JsonSerializable()
class RouteListItem {
  const RouteListItem({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.estimatedDurationMinutes,
    required this.status,
  });

  final int    id;
  final String name;
  final String code;
  final String? description;
  final int?   estimatedDurationMinutes;
  final String status;

  bool get isActive => status == 'ACTIVE';

  factory RouteListItem.fromJson(Map<String, dynamic> json) =>
      _$RouteListItemFromJson(json);

  Map<String, dynamic> toJson() => _$RouteListItemToJson(this);
}
