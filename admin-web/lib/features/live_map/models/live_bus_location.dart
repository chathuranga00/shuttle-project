class LiveBusLocation {
  final int busId;
  final String busNumber;
  final String? plateNumber;
  final int? tripId;
  final String? routeName;
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speedKmh;
  final DateTime updatedAt;
  final bool cleared;

  const LiveBusLocation({
    required this.busId,
    required this.busNumber,
    this.plateNumber,
    this.tripId,
    this.routeName,
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speedKmh,
    required this.updatedAt,
    this.cleared = false,
  });

  factory LiveBusLocation.fromJson(Map<String, dynamic> json) {
    return LiveBusLocation(
      busId: json['busId'] as int,
      busNumber: json['busNumber'] as String? ?? 'Bus #${json['busId']}',
      plateNumber: json['plateNumber'] as String?,
      tripId: json['tripId'] as int?,
      routeName: json['routeName'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      heading: json['heading'] != null ? (json['heading'] as num).toDouble() : null,
      speedKmh: json['speedKmh'] != null ? (json['speedKmh'] as num).toDouble() : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      cleared: json['cleared'] as bool? ?? false,
    );
  }
}
