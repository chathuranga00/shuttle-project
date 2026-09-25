class DriverTrip {
  final int id;
  final int routeId;
  final String routeName;
  final int busId;
  final String busNumber;
  final int driverId;
  final String driverName;
  final String status;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final String? notes;

  const DriverTrip({
    required this.id,
    required this.routeId,
    required this.routeName,
    required this.busId,
    required this.busNumber,
    required this.driverId,
    required this.driverName,
    required this.status,
    this.scheduledStart,
    this.scheduledEnd,
    this.actualStart,
    this.actualEnd,
    this.notes,
  });

  bool get isActive => status == 'IN_PROGRESS';
  bool get isScheduled => status == 'SCHEDULED';
  bool get isCompleted => status == 'COMPLETED';

  factory DriverTrip.fromJson(Map<String, dynamic> json) {
    return DriverTrip(
      id: json['id'] as int,
      routeId: json['routeId'] as int,
      routeName: json['routeName'] as String? ?? 'Route',
      busId: json['busId'] as int,
      busNumber: json['busNumber'] as String? ?? 'Bus',
      driverId: json['driverId'] as int,
      driverName: json['driverName'] as String? ?? '',
      status: json['status'] as String? ?? 'SCHEDULED',
      scheduledStart: json['scheduledStart'] != null
          ? DateTime.tryParse(json['scheduledStart'] as String)
          : null,
      scheduledEnd: json['scheduledEnd'] != null
          ? DateTime.tryParse(json['scheduledEnd'] as String)
          : null,
      actualStart: json['actualStart'] != null
          ? DateTime.tryParse(json['actualStart'] as String)
          : null,
      actualEnd: json['actualEnd'] != null
          ? DateTime.tryParse(json['actualEnd'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }
}
