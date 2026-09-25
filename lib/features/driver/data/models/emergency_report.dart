class EmergencyReport {
  final int id;
  final int driverId;
  final String driverName;
  final int? tripId;
  final String type;
  final String description;
  final String? location;
  final String status;
  final DateTime createdAt;

  const EmergencyReport({
    required this.id,
    required this.driverId,
    required this.driverName,
    this.tripId,
    required this.type,
    required this.description,
    this.location,
    required this.status,
    required this.createdAt,
  });

  factory EmergencyReport.fromJson(Map<String, dynamic> json) {
    return EmergencyReport(
      id: json['id'] as int,
      driverId: json['driverId'] as int,
      driverName: json['driverName'] as String? ?? 'Driver',
      tripId: json['tripId'] as int?,
      type: json['type'] as String? ?? 'EMERGENCY',
      description: json['description'] as String? ?? '',
      location: json['location'] as String?,
      status: json['status'] as String? ?? 'REPORTED',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
