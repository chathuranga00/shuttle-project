import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

class DashboardData {
  final int totalStudents;
  final int totalDrivers;
  final int totalBuses;
  final int activeTrips;
  final int todayPassengers;
  final double todayRevenue;
  final int activeMonthlyPasses;

  const DashboardData({
    this.totalStudents = 0,
    this.totalDrivers = 0,
    this.totalBuses = 0,
    this.activeTrips = 0,
    this.todayPassengers = 0,
    this.todayRevenue = 0.0,
    this.activeMonthlyPasses = 0,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      totalStudents: (json['totalStudents'] as num?)?.toInt() ?? 0,
      totalDrivers: (json['totalDrivers'] as num?)?.toInt() ?? 0,
      totalBuses: (json['totalBuses'] as num?)?.toInt() ?? 0,
      activeTrips: (json['activeTrips'] as num?)?.toInt() ?? 0,
      todayPassengers: (json['todayPassengers'] as num?)?.toInt() ?? 0,
      todayRevenue: (json['todayRevenue'] as num?)?.toDouble() ?? 0.0,
      activeMonthlyPasses: (json['activeMonthlyPasses'] as num?)?.toInt() ?? 0,
    );
  }
}

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get(ApiEndpoints.dashboard);
  return DashboardData.fromJson(response.data as Map<String, dynamic>);
});
