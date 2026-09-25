import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/core/utils/formatters.dart';
import 'package:admin_web/features/dashboard/dashboard_provider.dart';
import 'package:admin_web/features/students/students_provider.dart';
import 'package:admin_web/features/drivers/drivers_provider.dart';
import 'package:admin_web/features/buses/buses_provider.dart';
import 'package:admin_web/features/routes_stops/routes_stops_provider.dart';
import 'package:admin_web/features/trips/trips_provider.dart';
import 'package:admin_web/features/payments/payments_provider.dart';
import 'package:admin_web/features/settings/settings_provider.dart';

void main() {
  group('Formatters Tests', () {
    test('Currency formatter formats numbers with LKR prefix', () {
      expect(Formatters.formatCurrency(1500.5), 'LKR 1,500.50');
      expect(Formatters.formatCurrency('250'), 'LKR 250.00');
      expect(Formatters.formatCurrency(null), 'LKR 0.00');
    });

    test('Date formatter parses and formats dates', () {
      expect(Formatters.formatDate(DateTime(2026, 9, 25)), '2026-09-25');
      expect(Formatters.formatDate('2026-09-25T10:30:00Z'), '2026-09-25');
      expect(Formatters.formatDate(null), '-');
    });
  });

  group('Model Deserialization Tests', () {
    test('DashboardData.fromJson parses correctly', () {
      final json = {
        'totalStudents': 120,
        'totalDrivers': 10,
        'totalBuses': 6,
        'activeTrips': 2,
        'todayPassengers': 45,
        'todayRevenue': 2250.00,
        'activeMonthlyPasses': 30,
      };
      final data = DashboardData.fromJson(json);
      expect(data.totalStudents, 120);
      expect(data.totalDrivers, 10);
      expect(data.totalBuses, 6);
      expect(data.activeTrips, 2);
      expect(data.todayPassengers, 45);
      expect(data.todayRevenue, 2250.00);
      expect(data.activeMonthlyPasses, 30);
    });

    test('StudentItem.fromJson parses correctly', () {
      final json = {
        'id': 1,
        'userId': 2,
        'studentId': 'STU001',
        'fullName': 'Alice Wonder',
        'email': 'alice@uni.edu',
        'faculty': 'Computing',
        'department': 'CS',
        'enrollmentYear': 2024,
        'status': 'ACTIVE',
      };
      final student = StudentItem.fromJson(json);
      expect(student.studentId, 'STU001');
      expect(student.isActive, isTrue);
    });

    test('DriverItem.fromJson parses correctly', () {
      final json = {
        'driverId': 5,
        'userId': 12,
        'fullName': 'John Doe',
        'email': 'john@shuttle.dev',
        'licenseNumber': 'LIC-9988',
        'driverStatus': 'ACTIVE',
        'userStatus': 'ACTIVE',
        'assignedBusNumber': 'BUS-01',
        'assignedBusId': 3,
      };
      final driver = DriverItem.fromJson(json);
      expect(driver.fullName, 'John Doe');
      expect(driver.isAssigned, isTrue);
      expect(driver.assignedBusNumber, 'BUS-01');
    });

    test('BusItem.fromJson parses correctly', () {
      final json = {
        'id': 3,
        'busNumber': 'BUS-01',
        'plateNumber': 'WP-NC-1001',
        'capacity': 45,
        'model': 'Toyota Coaster',
        'status': 'ACTIVE',
      };
      final bus = BusItem.fromJson(json);
      expect(bus.busNumber, 'BUS-01');
      expect(bus.capacity, 45);
      expect(bus.isActive, isTrue);
    });

    test('TripItem.fromJson parses correctly', () {
      final json = {
        'id': 10,
        'routeId': 1,
        'routeName': 'Main Campus Loop',
        'busId': 2,
        'busNumber': 'BUS-02',
        'driverId': 5,
        'driverName': 'John Doe',
        'status': 'IN_PROGRESS',
        'scheduledStart': '2026-09-25T08:00:00Z',
      };
      final trip = TripItem.fromJson(json);
      expect(trip.id, 10);
      expect(trip.isInProgress, isTrue);
    });

    test('PaymentItem.fromJson parses correctly', () {
      final json = {
        'id': 100,
        'studentId': 1,
        'studentName': 'Alice Wonder',
        'studentCode': 'STU001',
        'amount': 500.0,
        'status': 'SUCCESS',
        'type': 'WALLET_TOPUP',
        'gatewayTransactionId': 'TX_12345',
        'createdAt': '2026-09-25T09:00:00Z',
      };
      final payment = PaymentItem.fromJson(json);
      expect(payment.gatewayTransactionId, 'TX_12345');
      expect(payment.amount, 500.0);
    });

    test('SystemSettingsData.fromJson parses correctly', () {
      final json = {
        'gpsRadiusMetres': 150,
        'gpsVerificationEnabled': true,
        'monthlyPassPrice': 5200.0,
      };
      final settings = SystemSettingsData.fromJson(json);
      expect(settings.gpsRadiusMetres, 150);
      expect(settings.gpsVerificationEnabled, isTrue);
      expect(settings.monthlyPassPrice, 5200.0);
    });
  });
}
