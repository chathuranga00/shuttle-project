import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/dio_client.dart';
import '../providers/connectivity_provider.dart';
import 'offline_action_queue_service.dart';

enum SyncStatus { idle, syncing, completed, error }

class SyncState {
  final SyncStatus status;
  final int pendingCount;
  final int syncedCount;
  final String? message;
  final DateTime? lastSyncTime;

  const SyncState({
    this.status = SyncStatus.idle,
    this.pendingCount = 0,
    this.syncedCount = 0,
    this.message,
    this.lastSyncTime,
  });

  SyncState copyWith({
    SyncStatus? status,
    int? pendingCount,
    int? syncedCount,
    String? message,
    DateTime? lastSyncTime,
  }) {
    return SyncState(
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
      syncedCount: syncedCount ?? this.syncedCount,
      message: message ?? this.message,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

/// Service that automatically synchronizes queued safe offline actions when
/// network connectivity is restored.
class OfflineSyncService extends StateNotifier<SyncState> {
  OfflineSyncService({
    required this.dio,
    required this.queueService,
    required this.ref,
  }) : super(const SyncState()) {
    _init();
  }

  final Dio dio;
  final OfflineActionQueueService queueService;
  final Ref ref;
  bool _isSyncing = false;

  void _init() {
    // Initial check of pending actions
    queueService.getPendingCount().then((count) {
      if (mounted) {
        state = state.copyWith(pendingCount: count);
      }
    });

    // Listen to network status changes
    ref.listen<bool>(isOnlineProvider, (previous, isOnline) {
      if (isOnline && (previous == false || previous == null)) {
        debugPrint('[OfflineSyncService] Device came online. Initiating sync...');
        syncNow();
      }
    });
  }

  /// Manually or automatically trigger synchronization of queued actions.
  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final queue = await queueService.getQueue();
      if (queue.isEmpty) {
        state = state.copyWith(
          status: SyncStatus.idle,
          pendingCount: 0,
        );
        _isSyncing = false;
        return;
      }

      state = state.copyWith(
        status: SyncStatus.syncing,
        pendingCount: queue.length,
        syncedCount: 0,
        message: 'Syncing ${queue.length} offline actions...',
      );

      int successCount = 0;

      for (final action in queue) {
        try {
          final options = Options(
            headers: {
              'Idempotency-Key': action.idempotencyKey,
            },
          );

          Response? response;
          if (action.method == 'POST') {
            response = await dio.post(
              action.endpoint,
              data: action.payload,
              options: options,
            );
          } else if (action.method == 'PATCH') {
            response = await dio.patch(
              action.endpoint,
              data: action.payload,
              options: options,
            );
          } else if (action.method == 'PUT') {
            response = await dio.put(
              action.endpoint,
              data: action.payload,
              options: options,
            );
          } else if (action.method == 'DELETE') {
            response = await dio.delete(
              action.endpoint,
              data: action.payload,
              options: options,
            );
          }

          if (response != null &&
              response.statusCode != null &&
              (response.statusCode! >= 200 && response.statusCode! < 300 ||
                  response.statusCode == 409)) {
            // Success or already processed (idempotent 409)
            await queueService.removeAction(action.actionId);
            successCount++;
          }
        } on DioException catch (dioErr) {
          final statusCode = dioErr.response?.statusCode;
          if (statusCode != null && statusCode >= 400 && statusCode < 500 && statusCode != 408) {
            // Client error (e.g. 400 or 404): remove bad action so it does not block the queue
            debugPrint('[OfflineSyncService] Action rejected by server ($statusCode): removing from queue');
            await queueService.removeAction(action.actionId);
          } else {
            // Connection error or 5xx server error: keep in queue and abort loop
            debugPrint('[OfflineSyncService] Connection error during sync: ${dioErr.message}');
            break;
          }
        } catch (e) {
          debugPrint('[OfflineSyncService] Unexpected error syncing action: $e');
        }
      }

      final remaining = await queueService.getPendingCount();
      state = state.copyWith(
        status: remaining == 0 ? SyncStatus.completed : SyncStatus.error,
        pendingCount: remaining,
        syncedCount: successCount,
        lastSyncTime: DateTime.now(),
        message: remaining == 0
            ? 'All offline actions synced successfully.'
            : '$remaining actions remain queued.',
      );
    } finally {
      _isSyncing = false;
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────
final offlineSyncServiceProvider =
    StateNotifierProvider<OfflineSyncService, SyncState>((ref) {
  final dio = ref.watch(dioClientProvider);
  final queueService = ref.watch(offlineActionQueueServiceProvider);
  return OfflineSyncService(
    dio: dio,
    queueService: queueService,
    ref: ref,
  );
});
