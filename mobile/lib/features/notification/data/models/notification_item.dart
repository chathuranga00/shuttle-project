class NotificationItem {
  final int id;
  final String type;
  final String title;
  final String message;
  final Map<String, dynamic>? dataPayload;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.dataPayload,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: (json['id'] as num).toInt(),
      type: (json['type'] as String?) ?? 'GENERAL',
      title: (json['title'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      dataPayload: json['dataPayload'] is Map<String, dynamic>
          ? json['dataPayload'] as Map<String, dynamic>
          : null,
      isRead: json['isRead'] as bool? ?? false,
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      if (dataPayload != null) 'dataPayload': dataPayload,
      'isRead': isRead,
      if (readAt != null) 'readAt': readAt!.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  NotificationItem copyWith({
    int? id,
    String? type,
    String? title,
    String? message,
    Map<String, dynamic>? dataPayload,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      dataPayload: dataPayload ?? this.dataPayload,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
