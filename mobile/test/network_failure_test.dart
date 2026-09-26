import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuttle/core/offline/offline_action_queue_service.dart';
import 'package:shuttle/core/offline/offline_cache_service.dart';
import 'package:shuttle/core/providers/connectivity_provider.dart';
import 'package:shuttle/core/widgets/connectivity_banner.dart';
import 'package:shuttle/features/routes/data/route_repository.dart';

class FailingDioAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'Network failure: No internet connection',
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Flutter Network Failure & Offline Resilience Tests', () {
    late OfflineCacheService cacheService;
    late OfflineActionQueueService queueService;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      const storage = FlutterSecureStorage();
      cacheService = OfflineCacheService(storage);
      queueService = OfflineActionQueueService(storage);
    });

    test('Network failure fallback: RouteRepository returns cached routes during network exception', () async {
      // 1. Seed the local cache with known routes
      final cachedRoutes = [
        {'id': 10, 'name': 'Green Line Express', 'code': 'GL-10', 'status': 'ACTIVE'},
        {'id': 20, 'name': 'City Circular', 'code': 'CC-20', 'status': 'ACTIVE'},
      ];
      await cacheService.cacheJson(OfflineCacheService.keyRoutes, cachedRoutes);

      // 2. Set up a Dio instance that simulates a network failure (connection error)
      final dio = Dio();
      dio.httpClientAdapter = FailingDioAdapter();

      // 3. Create repository with failing Dio and initialized cache
      final routeRepo = RouteRepository(dio, cacheService);

      // 4. Calling getRoutes should gracefully fall back to cached data without unhandled exception
      final routes = await routeRepo.getRoutes();
      expect(routes, isNotEmpty);
      expect(routes.length, equals(2));
      expect(routes.first.code, equals('GL-10'));
      expect(routes.last.name, equals('City Circular'));
    });

    test('Network failure protection: Critical financial & boarding actions are rejected offline', () {
      // Boarding confirmation
      expect(
        OfflineActionQueueService.isSafeAction('/api/boarding/confirm'),
        isFalse,
        reason: 'Boarding confirmation must never be queued offline without live server validation',
      );

      // Card verification
      expect(
        OfflineActionQueueService.isSafeAction('/api/cards/verify'),
        isFalse,
        reason: 'Student bus card verification requires live cryptographic validation',
      );

      // Wallet top-up
      expect(
        OfflineActionQueueService.isSafeAction('/api/wallet/top-up'),
        isFalse,
        reason: 'Financial top-ups must never be processed offline',
      );

      // Monthly pass purchase
      expect(
        OfflineActionQueueService.isSafeAction('/api/monthly-pass/purchase'),
        isFalse,
        reason: 'Monthly pass purchase requires live transaction processing',
      );

      // Enqueueing prohibited actions throws UnsupportedError
      expect(
        () => queueService.enqueueAction(endpoint: '/api/boarding/confirm', method: 'POST'),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => queueService.enqueueAction(endpoint: '/api/wallet/top-up', method: 'POST'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('Network failure resilience: Safe non-financial actions queue with idempotency keys', () async {
      // Notification read
      expect(OfflineActionQueueService.isSafeAction('/api/notifications/99/read'), isTrue);
      final readAction = await queueService.enqueueAction(
        endpoint: '/api/notifications/99/read',
        method: 'PATCH',
      );
      expect(readAction.idempotencyKey, isNotEmpty);

      // Emergency incident report
      expect(OfflineActionQueueService.isSafeAction('/api/driver/emergency-report'), isTrue);
      final emergencyAction = await queueService.enqueueAction(
        endpoint: '/api/driver/emergency-report',
        method: 'POST',
        payload: {'incidentType': 'BREAKDOWN', 'description': 'Engine stalled'},
      );
      expect(emergencyAction.idempotencyKey, isNotEmpty);

      final queue = await queueService.getQueue();
      expect(queue.length, equals(2));
      expect(queue.map((a) => a.endpoint), containsAll([
        '/api/notifications/99/read',
        '/api/driver/emergency-report',
      ]));
    });

    testWidgets('UI response to network failure: ConnectivityBanner alerts user without crashing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isOnlineProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ConnectivityBanner(
                child: Center(
                  child: Text('Protected Campus Transport Portal'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Content renders cleanly
      expect(find.text('Protected Campus Transport Portal'), findsOneWidget);

      // Offline warning banner is visible
      expect(find.textContaining('Offline Mode'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });
  });
}
