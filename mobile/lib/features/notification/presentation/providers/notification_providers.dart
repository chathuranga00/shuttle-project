import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/notification_item.dart';
import '../../data/notification_repository.dart';
import '../../services/push_notification_service.dart';

// ── Unread count provider ───────────────────────────────────────────────────
final unreadNotificationCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getUnreadCount();
});

// ── Notifications state ─────────────────────────────────────────────────────
class NotificationsState {
  final List<NotificationItem> items;
  final bool isLoading;
  final bool unreadOnly;
  final String? error;

  const NotificationsState({
    this.items = const [],
    this.isLoading = false,
    this.unreadOnly = false,
    this.error,
  });

  int get unreadCount => items.where((i) => !i.isRead).length;

  NotificationsState copyWith({
    List<NotificationItem>? items,
    bool? isLoading,
    bool? unreadOnly,
    String? error,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      unreadOnly: unreadOnly ?? this.unreadOnly,
      error: error,
    );
  }
}

// ── Notifications controller ────────────────────────────────────────────────
class NotificationsController extends StateNotifier<NotificationsState> {
  NotificationsController(
    this._repository,
    this._pushService,
    this._ref,
  ) : super(const NotificationsState()) {
    _init();
  }

  final NotificationRepository _repository;
  final PushNotificationService _pushService;
  final Ref _ref;

  void _init() {
    loadNotifications();

    // Listen to foreground incoming push notifications
    _pushService.onMessageReceived.listen((notification) {
      if (!mounted) return;
      state = state.copyWith(
        items: [notification, ...state.items],
      );
      _ref.invalidate(unreadNotificationCountProvider);
    });
  }

  Future<void> loadNotifications({bool? unreadOnly}) async {
    final filter = unreadOnly ?? state.unreadOnly;
    state = state.copyWith(isLoading: true, unreadOnly: filter, error: null);

    try {
      final items = await _repository.getNotifications(
        unreadOnly: filter ? true : null,
      );
      if (!mounted) return;
      state = state.copyWith(
        items: items,
        isLoading: false,
      );
      _ref.invalidate(unreadNotificationCountProvider);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void toggleUnreadFilter() {
    loadNotifications(unreadOnly: !state.unreadOnly);
  }

  Future<void> markAsRead(int notificationId) async {
    // Optimistic UI update
    final updatedList = state.items.map((item) {
      if (item.id == notificationId) {
        return item.copyWith(isRead: true, readAt: DateTime.now());
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedList);
    _ref.invalidate(unreadNotificationCountProvider);

    await _repository.markAsRead(notificationId);
  }

  Future<void> markAllAsRead() async {
    // Optimistic UI update
    final updatedList = state.items.map((item) {
      return item.copyWith(isRead: true, readAt: DateTime.now());
    }).toList();

    state = state.copyWith(items: updatedList);
    _ref.invalidate(unreadNotificationCountProvider);

    await _repository.markAllAsRead();
  }

  Future<void> refresh() => loadNotifications();
}

// ── Provider ─────────────────────────────────────────────────────────────────
final notificationsControllerProvider =
    StateNotifierProvider<NotificationsController, NotificationsState>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  final pushService = ref.watch(pushNotificationServiceProvider);
  return NotificationsController(repo, pushService, ref);
});
