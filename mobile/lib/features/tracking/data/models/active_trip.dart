class ActiveTrip {
  final int tripId;
  final int? routeId;
  final String routeName;
  final String routeCode;
  final int? busId;
  final String busNumber;
  final String status;
  final DateTime? actualStart;

  const ActiveTrip({
    required this.tripId,
    this.routeId,
    required this.routeName,
    required this.routeCode,
    this.busId,
    required this.busNumber,
    required this.status,
    this.actualStart,
  });

  factory ActiveTrip.fromJson(Map<String, dynamic> json) {
    return ActiveTrip(
      tripId: (json['tripId'] as num).toInt(),
      routeId: (json['routeId'] as num?)?.toInt(),
      routeName: json['routeName'] as String? ?? 'Shuttle',
      routeCode: json['routeCode'] as String? ?? '',
      busId: (json['busId'] as num?)?.toInt(),
      busNumber: json['busNumber'] as String? ?? '',
      status: json['status'] as String? ?? 'IN_PROGRESS',
      actualStart: json['actualStart'] != null
          ? DateTime.tryParse(json['actualStart'] as String)
          : null,
    );
  }
}
