import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuttle/features/auth/presentation/providers/auth_provider.dart';
import 'package:shuttle/features/driver/data/models/driver_assignment.dart';
import 'package:shuttle/features/driver/data/models/driver_trip.dart';
import 'package:shuttle/features/driver/data/models/driver_trip_history_item.dart';
import 'package:shuttle/features/driver/data/models/trip_summary.dart';
import 'package:shuttle/features/driver/presentation/providers/driver_providers.dart';
import 'package:shuttle/features/driver/presentation/screens/assigned_bus_screen.dart';
import 'package:shuttle/features/driver/presentation/screens/assigned_route_screen.dart';
import 'package:shuttle/features/driver/presentation/screens/current_trip_screen.dart';
import 'package:shuttle/features/driver/presentation/screens/driver_dashboard_screen.dart';
import 'package:shuttle/features/driver/presentation/screens/driver_trip_history_screen.dart';
import 'package:shuttle/features/driver/presentation/screens/emergency_report_screen.dart';
import 'package:shuttle/features/driver/presentation/screens/scan_student_card_screen.dart';

// ── Mock AuthNotifier ─────────────────────────────────────────────────────────

class _MockAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _MockAuthNotifier()
      : super(const AuthState(
          status: AuthStatus.authenticated,
          role: 'DRIVER',
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Test Fixtures ─────────────────────────────────────────────────────────────

const _bus = DriverBus(
  id: 1,
  busNumber: 'BUS-001',
  plateNumber: 'WP-NC-1234',
  capacity: 45,
  status: 'ACTIVE',
);

const _stop1 = DriverRouteStop(
  id: 101,
  name: 'Main Campus Gate',
  qrCode: 'STOP-001',
  sequence: 1,
);

const _stop2 = DriverRouteStop(
  id: 102,
  name: 'Engineering Faculty',
  qrCode: 'STOP-002',
  sequence: 2,
);

const _route = DriverRoute(
  id: 1,
  name: 'Campus Express',
  code: 'RT-01',
  description: 'Fast loop connecting hostels to lecture halls',
  estimatedDurationMinutes: 25,
  status: 'ACTIVE',
  stops: [_stop1, _stop2],
);

const _assignment = DriverAssignment(
  driverId: 10,
  driverName: 'John Driver',
  licenseNumber: 'LIC-998877',
  driverStatus: 'ACTIVE',
  bus: _bus,
  route: _route,
);

final _activeTrip = DriverTrip(
  id: 50,
  routeId: 1,
  routeName: 'Campus Express',
  busId: 1,
  busNumber: 'BUS-001',
  driverId: 10,
  driverName: 'John Driver',
  status: 'IN_PROGRESS',
  scheduledStart: DateTime(2026, 9, 25, 8, 30),
  actualStart: DateTime(2026, 9, 25, 8, 32),
);

final _scheduledTrip = DriverTrip(
  id: 51,
  routeId: 1,
  routeName: 'Campus Express',
  busId: 1,
  busNumber: 'BUS-001',
  driverId: 10,
  driverName: 'John Driver',
  status: 'SCHEDULED',
  scheduledStart: DateTime(2026, 9, 25, 14, 0),
);

final _tripSummary = TripSummary(
  tripId: 50,
  totalPassengers: 12,
  monthlyPassCount: 8,
  payPerTripCount: 4,
  recentBoardings: [
    BoardingItem(
      id: 201,
      studentId: 1,
      studentName: 'Kasun Perera',
      stopName: 'Main Campus Gate',
      boardedAt: DateTime(2026, 9, 25, 8, 35),
      paymentStatus: 'PASS',
    ),
    BoardingItem(
      id: 202,
      studentId: 2,
      studentName: 'Nimali Silva',
      stopName: 'Engineering Faculty',
      boardedAt: DateTime(2026, 9, 25, 8, 38),
      fareAmount: 50.0,
      paymentStatus: 'PAID',
    ),
  ],
);

final _historyItem = DriverTripHistoryItem(
  id: 49,
  routeId: 1,
  routeName: 'Campus Express',
  busId: 1,
  busNumber: 'BUS-001',
  status: 'COMPLETED',
  scheduledStart: DateTime(2026, 9, 24, 8, 30),
  scheduledEnd: DateTime(2026, 9, 24, 9, 0),
  actualStart: DateTime(2026, 9, 24, 8, 31),
  actualEnd: DateTime(2026, 9, 24, 8, 58),
  passengerCount: 22,
  monthlyPassCount: 15,
  payPerTripCount: 7,
);

void main() {
  group('Driver Screens UI & Functionality Tests', () {
    // ── Driver Dashboard Screen Tests ─────────────────────────────────────────

    testWidgets('Driver Dashboard displays driver info, on-duty status and nav options',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _MockAuthNotifier()),
            currentTripProvider.overrideWith((ref) async => null),
            driverAssignmentProvider.overrideWith((ref) async => _assignment),
          ],
          child: const MaterialApp(home: DriverDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Driver Portal'), findsOneWidget);
      expect(find.text('John Driver'), findsOneWidget);
      expect(find.text('ON DUTY'), findsOneWidget);
      expect(find.text('No Trips Scheduled for Today'), findsOneWidget);
      expect(find.text('Current Trip & Live Boardings'), findsOneWidget);
      expect(find.text('Scan Student Card'), findsOneWidget);
      expect(find.text('Assigned Route'), findsOneWidget);
      expect(find.text('Assigned Bus Details'), findsOneWidget);
      expect(find.text('Emergency Report'), findsOneWidget);
      expect(find.text('Trip History'), findsOneWidget);
    });

    testWidgets('Driver Dashboard displays active trip with metrics and VIEW/END buttons',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _MockAuthNotifier()),
            currentTripProvider.overrideWith((ref) async => _activeTrip),
            liveTripSummaryProvider(50)
                .overrideWith((ref) => Stream.value(_tripSummary)),
            driverAssignmentProvider.overrideWith((ref) async => _assignment),
          ],
          child: const MaterialApp(home: DriverDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Campus Express'), findsOneWidget);
      expect(find.text('Bus BUS-001'), findsWidgets);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('VIEW LIVE TRIP'), findsOneWidget);
      expect(find.text('END TRIP'), findsOneWidget);

      // Verify passenger counts are rendered
      expect(find.text('12'), findsOneWidget); // Total
      expect(find.text('8'), findsOneWidget);  // Pass
      expect(find.text('4'), findsOneWidget);  // Pay-per-trip
    });

    testWidgets('Driver Dashboard displays scheduled trip with START TRIP button',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _MockAuthNotifier()),
            currentTripProvider.overrideWith((ref) async => _scheduledTrip),
            driverAssignmentProvider.overrideWith((ref) async => _assignment),
          ],
          child: const MaterialApp(home: DriverDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SCHEDULED'), findsOneWidget);
      expect(find.text('START TRIP'), findsOneWidget);
    });

    // ── Current Trip Screen Tests ─────────────────────────────────────────────

    testWidgets('Current Trip Screen displays live feed and boardings',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentTripProvider.overrideWith((ref) async => _activeTrip),
            liveTripSummaryProvider(50)
                .overrideWith((ref) => Stream.value(_tripSummary)),
          ],
          child: const MaterialApp(home: CurrentTripScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Current Trip'), findsOneWidget);
      expect(find.text('LIVE • Auto-refreshing every 10s'), findsOneWidget);
      expect(find.text('Kasun Perera'), findsOneWidget);
      expect(find.text('Main Campus Gate'), findsOneWidget);
      expect(find.text('PASS'), findsOneWidget);

      expect(find.text('Nimali Silva'), findsOneWidget);
      expect(find.text('Engineering Faculty'), findsOneWidget);
      expect(find.text('PAID'), findsOneWidget);

      expect(find.text('END TRIP'), findsOneWidget);
    });

    // ── Assigned Bus Screen Tests ─────────────────────────────────────────────

    testWidgets('Assigned Bus Screen displays bus specs and driver info',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            driverAssignmentProvider.overrideWith((ref) async => _assignment),
          ],
          child: const MaterialApp(home: AssignedBusScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Assigned Bus'), findsOneWidget);
      expect(find.text('Bus BUS-001'), findsOneWidget);
      expect(find.text('WP-NC-1234'), findsOneWidget);
      expect(find.text('45 Passengers'), findsOneWidget);
      expect(find.text('LIC-998877'), findsOneWidget);
    });

    // ── Assigned Route Screen Tests ───────────────────────────────────────────

    testWidgets('Assigned Route Screen displays route and sequence of stops',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            driverAssignmentProvider.overrideWith((ref) async => _assignment),
          ],
          child: const MaterialApp(home: AssignedRouteScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Assigned Route'), findsOneWidget);
      expect(find.text('RT-01'), findsOneWidget);
      expect(find.text('Campus Express'), findsOneWidget);
      expect(find.text('Main Campus Gate'), findsOneWidget);
      expect(find.text('Engineering Faculty'), findsOneWidget);
      expect(find.text('ORIGIN'), findsOneWidget);
      expect(find.text('TERMINUS'), findsOneWidget);
    });

    // ── Emergency Report Screen Tests ─────────────────────────────────────────

    testWidgets('Emergency Report Screen displays incident types and submit button',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentTripProvider.overrideWith((ref) async => _activeTrip),
          ],
          child: const MaterialApp(home: EmergencyReportScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Emergency Report'), findsOneWidget);
      expect(find.text('Mechanical Breakdown'), findsOneWidget);
      expect(find.text('Accident / Collision'), findsOneWidget);
      expect(find.text('Medical Emergency'), findsOneWidget);
      expect(find.text('Major Route Delay'), findsOneWidget);
      expect(find.text('Safety / Security'), findsOneWidget);
      expect(find.text('SUBMIT EMERGENCY REPORT'), findsOneWidget);
    });

    // ── Driver Trip History Screen Tests ──────────────────────────────────────

    testWidgets('Driver Trip History Screen displays completed trips',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            driverTripHistoryProvider.overrideWith((ref) async => [_historyItem]),
          ],
          child: const MaterialApp(home: DriverTripHistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trip History'), findsOneWidget);
      expect(find.text('Campus Express'), findsOneWidget);
      expect(find.text('Bus BUS-001'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.text('22'), findsOneWidget); // Passenger count
      expect(find.text('15'), findsOneWidget); // Pass count
      expect(find.text('7'), findsOneWidget);  // Pay-per-trip count
    });

    // ── Scan Student Card Screen Tests ────────────────────────────────────────

    testWidgets('Scan Student Card Screen displays manual entry toggle and form',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ScanStudentCardScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Verify Student Card'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_rounded), findsOneWidget);

      // Tap to toggle manual input
      await tester.tap(find.byIcon(Icons.keyboard_rounded));
      await tester.pump();

      expect(find.text('Manual Card Check'), findsOneWidget);
      expect(find.text('Verify Card'), findsOneWidget);
    });
  });
}
