import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuttle/core/offline/offline_action_queue_service.dart';
import 'package:shuttle/core/offline/offline_cache_service.dart';
import 'package:shuttle/core/providers/connectivity_provider.dart';
import 'package:shuttle/core/widgets/connectivity_banner.dart';
import 'package:shuttle/features/notification/data/models/notification_item.dart';
import 'package:shuttle/features/notification/presentation/providers/notification_providers.dart';
import 'package:shuttle/features/notification/presentation/widgets/notification_bell_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineActionQueueService Tests', () {
    late OfflineActionQueueService queueService;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      const storage = FlutterSecureStorage();
      queueService = OfflineActionQueueService(storage);
    });

    test('isSafeAction accurately identifies safe vs prohibited offline actions', () {
      // Safe non-payment actions
      expect(OfflineActionQueueService.isSafeAction('/api/notifications/123/read'), isTrue);
      expect(OfflineActionQueueService.isSafeAction('/api/notifications/read-all'), isTrue);
      expect(OfflineActionQueueService.isSafeAction('/api/driver/emergency-report'), isTrue);
      expect(OfflineActionQueueService.isSafeAction('/api/devices'), isTrue);

      // Prohibited payment and boarding verification actions
      expect(OfflineActionQueueService.isSafeAction('/api/boarding/confirm'), isFalse);
      expect(OfflineActionQueueService.isSafeAction('/api/boarding/scan'), isFalse);
      expect(OfflineActionQueueService.isSafeAction('/api/cards/verify'), isFalse);
      expect(OfflineActionQueueService.isSafeAction('/api/wallet/topup/initiate'), isFalse);
      expect(OfflineActionQueueService.isSafeAction('/api/wallet/top-up'), isFalse);
      expect(OfflineActionQueueService.isSafeAction('/api/monthly-pass/purchase'), isFalse);
      expect(OfflineActionQueueService.isSafeAction('/api/payments/checkout'), isFalse);
    });

    test('enqueueAction throws UnsupportedError for prohibited payment/boarding actions', () async {
      expect(
        () => queueService.enqueueAction(
          endpoint: '/api/boarding/confirm',
          method: 'POST',
        ),
        throwsA(isA<UnsupportedError>()),
      );

      expect(
        () => queueService.enqueueAction(
          endpoint: '/api/wallet/top-up',
          method: 'POST',
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('enqueueAction successfully queues safe actions with idempotency keys', () async {
      final action = await queueService.enqueueAction(
        endpoint: '/api/notifications/42/read',
        method: 'PATCH',
      );

      expect(action.actionId, isNotEmpty);
      expect(action.idempotencyKey, isNotEmpty);
      expect(action.method, equals('PATCH'));
      expect(action.endpoint, equals('/api/notifications/42/read'));

      final queue = await queueService.getQueue();
      expect(queue.length, equals(1));
      expect(queue.first.actionId, equals(action.actionId));
      expect(queue.first.idempotencyKey, equals(action.idempotencyKey));

      // Remove after sync
      await queueService.removeAction(action.actionId);
      final remaining = await queueService.getPendingCount();
      expect(remaining, equals(0));
    });
  });

  group('OfflineCacheService Tests', () {
    late OfflineCacheService cacheService;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      const storage = FlutterSecureStorage();
      cacheService = OfflineCacheService(storage);
    });

    test('cacheJson and getCachedJson correctly persist and restore structured data', () async {
      final sampleRoutes = [
        {'id': 1, 'name': 'Campus Express', 'code': 'ROUTE-A', 'status': 'ACTIVE'},
        {'id': 2, 'name': 'Hostel Shuttle', 'code': 'ROUTE-B', 'status': 'ACTIVE'},
      ];

      await cacheService.cacheJson(OfflineCacheService.keyRoutes, sampleRoutes);

      final retrieved = await cacheService.getCachedJson(OfflineCacheService.keyRoutes);
      expect(retrieved, isNotNull);
      expect(retrieved is List, isTrue);
      expect((retrieved as List).length, equals(2));
      expect(retrieved.first['code'], equals('ROUTE-A'));
    });
  });

  group('NotificationItem Model Tests', () {
    test('fromJson and toJson maintain all fields correctly', () {
      final json = {
        'id': 101,
        'type': 'BOARDING',
        'title': 'Boarding Confirmed',
        'message': 'You boarded at Main Gate on Route A',
        'dataPayload': {'tripId': 5, 'fare': 60.0},
        'isRead': false,
        'readAt': null,
        'createdAt': '2026-09-26T01:00:00.000Z',
      };

      final item = NotificationItem.fromJson(json);
      expect(item.id, equals(101));
      expect(item.type, equals('BOARDING'));
      expect(item.title, equals('Boarding Confirmed'));
      expect(item.dataPayload?['tripId'], equals(5));
      expect(item.isRead, isFalse);

      final copy = item.copyWith(isRead: true, readAt: DateTime.parse('2026-09-26T01:05:00.000Z'));
      expect(copy.isRead, isTrue);
      expect(copy.readAt, isNotNull);

      final serialized = copy.toJson();
      expect(serialized['isRead'], isTrue);
      expect(serialized['id'], equals(101));
    });
  });

  group('Notification UI Widget Tests', () {
    testWidgets('NotificationBellButton displays bell icon and badge with unread count', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unreadNotificationCountProvider.overrideWith((ref) => Future.value(3)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: NotificationBellButton(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('ConnectivityBanner displays offline notification banner when offline', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isOnlineProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ConnectivityBanner(
                child: Text('Main Screen Content'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Main Screen Content'), findsOneWidget);
      expect(find.textContaining('Offline Mode'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });
  });
}
