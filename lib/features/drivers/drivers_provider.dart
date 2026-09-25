import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

class DriverItem {
  final int driverId;
  final int userId;
  final String fullName;
  final String email;
  final String? phone;
  final String licenseNumber;
  final String? licenseExpiry;
  final String driverStatus;
  final String userStatus;
  final int? assignedBusId;
  final String? assignedBusNumber;
  final int? assignedRouteId;
  final String? assignedRouteName;

  const DriverItem({
    required this.driverId,
    required this.userId,
    required this.fullName,
    required this.email,
    this.phone,
    required this.licenseNumber,
    this.licenseExpiry,
    required this.driverStatus,
    required this.userStatus,
    this.assignedBusId,
    this.assignedBusNumber,
    this.assignedRouteId,
    this.assignedRouteName,
  });

  factory DriverItem.fromJson(Map<String, dynamic> json) {
    return DriverItem(
      driverId: (json['driverId'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      licenseNumber: json['licenseNumber'] as String? ?? '',
      licenseExpiry: json['licenseExpiry'] as String?,
      driverStatus: json['driverStatus'] as String? ?? 'ACTIVE',
      userStatus: json['userStatus'] as String? ?? 'ACTIVE',
      assignedBusId: (json['assignedBusId'] as num?)?.toInt(),
      assignedBusNumber: json['assignedBusNumber'] as String?,
      assignedRouteId: (json['assignedRouteId'] as num?)?.toInt(),
      assignedRouteName: json['assignedRouteName'] as String?,
    );
  }

  bool get isAssigned => assignedBusId != null;
  bool get isActive => driverStatus.toUpperCase() == 'ACTIVE';
}

final driversProvider = FutureProvider.autoDispose<List<DriverItem>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get(ApiEndpoints.drivers);
  final list = response.data as List? ?? [];
  return list.map((item) => DriverItem.fromJson(item as Map<String, dynamic>)).toList();
});
