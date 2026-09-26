class DriverTripHistoryItem {
  final int id;
  final int routeId;
  final String routeName;
  final int busId;
  final String busNumber;
  final String status;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final int passengerCount;
  final int monthlyPassCount;
  final int payPerTripCount;
  final String? notes;
  final DateTime? createdAt;

  const DriverTripHistoryItem({
    required this.id,
    required this.routeId,
    required this.routeName,
    required this.busId,
    required this.busNumber,
    required this.status,
    this.scheduledStart,
    this.scheduledEnd,
    this.actualStart,
    this.actualEnd,
    required this.passengerCount,
    required this.monthlyPassCount,
    required this.payPerTripCount,
    this.notes,
    this.createdAt,
  });

  factory DriverTripHistoryItem.fromJson(Map<String, dynamic> json) {
    return DriverTripHistoryItem(
      id: json['id'] as int,
      routeId: json['routeId'] as int,
      routeName: json['routeName'] as String? ?? 'Route',
      busId: json['busId'] as int,
      busNumber: json['busNumber'] as String? ?? 'Bus',
      status: json['status'] as String? ?? 'COMPLETED',
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
      passengerCount: json['passengerCount'] as int? ?? 0,
      monthlyPassCount: json['monthlyPassCount'] as int? ?? 0,
      payPerTripCount: json['payPerTripCount'] as int? ?? 0,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}
