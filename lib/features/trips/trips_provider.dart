import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

class TripItem {
  final int id;
  final int routeId;
  final String routeName;
  final int busId;
  final String busNumber;
  final int driverId;
  final String driverName;
  final String status;
  final String scheduledStart;
  final String? scheduledEnd;
  final String? actualStart;
  final String? actualEnd;
  final String? notes;

  const TripItem({
    required this.id,
    required this.routeId,
    required this.routeName,
    required this.busId,
    required this.busNumber,
    required this.driverId,
    required this.driverName,
    required this.status,
    required this.scheduledStart,
    this.scheduledEnd,
    this.actualStart,
    this.actualEnd,
    this.notes,
  });

  factory TripItem.fromJson(Map<String, dynamic> json) {
    return TripItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      routeId: (json['routeId'] as num?)?.toInt() ?? 0,
      routeName: json['routeName'] as String? ?? 'Route',
      busId: (json['busId'] as num?)?.toInt() ?? 0,
      busNumber: json['busNumber'] as String? ?? 'Bus',
      driverId: (json['driverId'] as num?)?.toInt() ?? 0,
      driverName: json['driverName'] as String? ?? 'Driver',
      status: json['status'] as String? ?? 'SCHEDULED',
      scheduledStart: json['scheduledStart'] as String? ?? '',
      scheduledEnd: json['scheduledEnd'] as String?,
      actualStart: json['actualStart'] as String?,
      actualEnd: json['actualEnd'] as String?,
      notes: json['notes'] as String?,
    );
  }

  bool get isScheduled => status.toUpperCase() == 'SCHEDULED';
  bool get isInProgress => status.toUpperCase() == 'IN_PROGRESS';
  bool get isCompleted => status.toUpperCase() == 'COMPLETED';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';
}

final tripsProvider = FutureProvider.autoDispose<List<TripItem>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get(ApiEndpoints.trips);
  final list = response.data as List? ?? [];
  return list.map((item) => TripItem.fromJson(item as Map<String, dynamic>)).toList();
});
