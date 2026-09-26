class DriverBus {
  final int id;
  final String busNumber;
  final String plateNumber;
  final int capacity;
  final String status;

  const DriverBus({
    required this.id,
    required this.busNumber,
    required this.plateNumber,
    required this.capacity,
    required this.status,
  });

  factory DriverBus.fromJson(Map<String, dynamic> json) {
    return DriverBus(
      id: json['id'] as int,
      busNumber: json['busNumber'] as String? ?? '',
      plateNumber: json['plateNumber'] as String? ?? '',
      capacity: json['capacity'] as int? ?? 0,
      status: json['status'] as String? ?? 'ACTIVE',
    );
  }
}

class DriverRouteStop {
  final int id;
  final String name;
  final String qrCode;
  final int sequence;
  final double? latitude;
  final double? longitude;

  const DriverRouteStop({
    required this.id,
    required this.name,
    required this.qrCode,
    required this.sequence,
    this.latitude,
    this.longitude,
  });

  factory DriverRouteStop.fromJson(Map<String, dynamic> json) {
    return DriverRouteStop(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      qrCode: json['qrCode'] as String? ?? '',
      sequence: json['sequence'] as int? ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

class DriverRoute {
  final int id;
  final String name;
  final String code;
  final String? description;
  final int? estimatedDurationMinutes;
  final String status;
  final List<DriverRouteStop> stops;

  const DriverRoute({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.estimatedDurationMinutes,
    required this.status,
    required this.stops,
  });

  factory DriverRoute.fromJson(Map<String, dynamic> json) {
    final stopsList = (json['stops'] as List<dynamic>? ?? [])
        .map((s) => DriverRouteStop.fromJson(s as Map<String, dynamic>))
        .toList();
    return DriverRoute(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      description: json['description'] as String?,
      estimatedDurationMinutes: json['estimatedDurationMinutes'] as int?,
      status: json['status'] as String? ?? 'ACTIVE',
      stops: stopsList,
    );
  }
}

class DriverAssignment {
  final int driverId;
  final String driverName;
  final String licenseNumber;
  final String driverStatus;
  final DriverBus? bus;
  final DriverRoute? route;

  const DriverAssignment({
    required this.driverId,
    required this.driverName,
    required this.licenseNumber,
    required this.driverStatus,
    this.bus,
    this.route,
  });

  factory DriverAssignment.fromJson(Map<String, dynamic> json) {
    return DriverAssignment(
      driverId: json['driverId'] as int,
      driverName: json['driverName'] as String? ?? '',
      licenseNumber: json['licenseNumber'] as String? ?? '',
      driverStatus: json['driverStatus'] as String? ?? 'ACTIVE',
      bus: json['bus'] != null
          ? DriverBus.fromJson(json['bus'] as Map<String, dynamic>)
          : null,
      route: json['route'] != null
          ? DriverRoute.fromJson(json['route'] as Map<String, dynamic>)
          : null,
    );
  }
}
