import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Represents a safe non-payment action queued while offline.
class QueuedAction {
  final String actionId;
  final String endpoint;
  final String method; // 'POST' | 'PATCH' | 'PUT' | 'DELETE'
  final Map<String, dynamic>? payload;
  final String idempotencyKey;
  final DateTime createdAt;

  const QueuedAction({
    required this.actionId,
    required this.endpoint,
    required this.method,
    this.payload,
    required this.idempotencyKey,
    required this.createdAt,
  });

  factory QueuedAction.fromJson(Map<String, dynamic> json) {
    return QueuedAction(
      actionId: json['actionId'] as String,
      endpoint: json['endpoint'] as String,
      method: json['method'] as String,
      payload: json['payload'] is Map<String, dynamic>
          ? json['payload'] as Map<String, dynamic>
          : null,
      idempotencyKey: json['idempotencyKey'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'actionId': actionId,
      'endpoint': endpoint,
      'method': method,
      if (payload != null) 'payload': payload,
      'idempotencyKey': idempotencyKey,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// Service that maintains the queue of safe actions to be executed when online.
/// Strictly enforces that payment and boarding confirmation actions cannot be queued.
class OfflineActionQueueService {
  OfflineActionQueueService(this._storage);

  final FlutterSecureStorage _storage;
  static const String _queueKey = 'offline_actions_queue';
  static const _uuid = Uuid();

  /// Check whether an action/endpoint is safe to queue offline.
  /// Strictly rejects payments, top-ups, pass purchases, and boarding confirmations.
  static bool isSafeAction(String endpoint) {
    final lower = endpoint.toLowerCase();

    // Critical security checks - NEVER queue payment or boarding confirmation
    if (lower.contains('/boarding/confirm') ||
        lower.contains('/boarding/scan') ||
        lower.contains('/cards/verify') ||
        lower.contains('/wallet/topup') ||
        lower.contains('/wallet/top-up') ||
        lower.contains('/monthly-pass/purchase') ||
        lower.contains('/payment')) {
      return false;
    }

    // Explicitly allowed safe actions
    if (lower.contains('/notifications') ||
        lower.contains('/driver/emergency') ||
        lower.contains('/devices')) {
      return true;
    }

    // Default safe check
    return false;
  }

  /// Enqueue an action. Throws [UnsupportedError] if the action is not safe.
  Future<QueuedAction> enqueueAction({
    required String endpoint,
    required String method,
    Map<String, dynamic>? payload,
    String? idempotencyKey,
  }) async {
    if (!isSafeAction(endpoint)) {
      throw UnsupportedError(
        'Payments and boarding confirmation must always require live server confirmation. '
        'Offline queueing is not permitted for: $endpoint',
      );
    }

    final action = QueuedAction(
      actionId: _uuid.v4(),
      endpoint: endpoint,
      method: method.toUpperCase(),
      payload: payload,
      idempotencyKey: idempotencyKey ?? _uuid.v4(),
      createdAt: DateTime.now(),
    );

    final currentQueue = await getQueue();
    currentQueue.add(action);
    await _saveQueue(currentQueue);

    return action;
  }

  /// Get list of currently queued actions.
  Future<List<QueuedAction>> getQueue() async {
    try {
      final raw = await _storage.read(key: _queueKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => QueuedAction.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Remove an action by ID after successful synchronization.
  Future<void> removeAction(String actionId) async {
    final currentQueue = await getQueue();
    currentQueue.removeWhere((a) => a.actionId == actionId);
    await _saveQueue(currentQueue);
  }

  /// Total count of pending queued actions.
  Future<int> getPendingCount() async {
    final queue = await getQueue();
    return queue.length;
  }

  /// Clear the entire action queue.
  Future<void> clearQueue() async {
    await _storage.delete(key: _queueKey);
  }

  Future<void> _saveQueue(List<QueuedAction> queue) async {
    try {
      final jsonString = jsonEncode(queue.map((a) => a.toJson()).toList());
      await _storage.write(key: _queueKey, value: jsonString);
    } catch (_) {}
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────
final offlineActionQueueServiceProvider =
    Provider<OfflineActionQueueService>((ref) {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  return OfflineActionQueueService(storage);
});
