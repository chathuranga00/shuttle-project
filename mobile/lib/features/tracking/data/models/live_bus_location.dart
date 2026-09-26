class LiveBusLocation {
  final int? id;
  final int busId;
  final String? busNumber;
  final int? tripId;
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speedKmh;
  final DateTime updatedAt;
  final bool cleared;

  const LiveBusLocation({
    this.id,
    required this.busId,
    this.busNumber,
    this.tripId,
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speedKmh,
    required this.updatedAt,
    this.cleared = false,
  });

  factory LiveBusLocation.fromJson(Map<String, dynamic> json) {
    return LiveBusLocation(
      id: json['id'] as int?,
      busId: (json['busId'] as num?)?.toInt() ?? 0,
      busNumber: json['busNumber'] as String?,
      tripId: (json['tripId'] as num?)?.toInt(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      speedKmh: (json['speedKmh'] as num?)?.toDouble() ?? (json['speed'] as num?)?.toDouble(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      cleared: json['cleared'] as bool? ?? false,
    );
  }
}
