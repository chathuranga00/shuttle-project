class CardVerificationResult {
  final String cardId;
  final String studentName;
  final String cardStatus;
  final String monthlyPassStatus; // "ACTIVE" | "NONE" | "EXPIRED"

  const CardVerificationResult({
    required this.cardId,
    required this.studentName,
    required this.cardStatus,
    required this.monthlyPassStatus,
  });

  bool get isValid => cardStatus == 'ACTIVE';
  bool get hasActivePass => monthlyPassStatus == 'ACTIVE';

  factory CardVerificationResult.fromJson(Map<String, dynamic> json) {
    return CardVerificationResult(
      cardId: json['cardId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? 'Student',
      cardStatus: json['cardStatus'] as String? ?? 'UNKNOWN',
      monthlyPassStatus: json['monthlyPassStatus'] as String? ?? 'NONE',
    );
  }
}
