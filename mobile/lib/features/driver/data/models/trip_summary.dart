class BoardingItem {
  final int id;
  final int studentId;
  final String studentName;
  final String stopName;
  final DateTime boardedAt;
  final double? fareAmount;
  final String paymentStatus;

  const BoardingItem({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.stopName,
    required this.boardedAt,
    this.fareAmount,
    required this.paymentStatus,
  });

  bool get isMonthlyPass => paymentStatus == 'PASS';

  factory BoardingItem.fromJson(Map<String, dynamic> json) {
    return BoardingItem(
      id: json['id'] as int,
      studentId: json['studentId'] as int,
      studentName: json['studentName'] as String? ?? 'Student',
      stopName: json['stopName'] as String? ?? 'Stop',
      boardedAt:
          DateTime.tryParse(json['boardedAt'] as String? ?? '') ?? DateTime.now(),
      fareAmount: (json['fareAmount'] as num?)?.toDouble(),
      paymentStatus: json['paymentStatus'] as String? ?? 'UNPAID',
    );
  }
}

class TripSummary {
  final int tripId;
  final int totalPassengers;
  final int monthlyPassCount;
  final int payPerTripCount;
  final List<BoardingItem> recentBoardings;

  const TripSummary({
    required this.tripId,
    required this.totalPassengers,
    required this.monthlyPassCount,
    required this.payPerTripCount,
    required this.recentBoardings,
  });

  factory TripSummary.fromJson(Map<String, dynamic> json) {
    final list = (json['recentBoardings'] as List<dynamic>? ?? [])
        .map((e) => BoardingItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return TripSummary(
      tripId: json['tripId'] as int,
      totalPassengers: json['totalPassengers'] as int? ?? 0,
      monthlyPassCount: json['monthlyPassCount'] as int? ?? 0,
      payPerTripCount: json['payPerTripCount'] as int? ?? 0,
      recentBoardings: list,
    );
  }
}
