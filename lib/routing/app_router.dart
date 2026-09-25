import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_provider.dart';
import '../features/layout/admin_shell.dart';
import '../features/login/login_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/students/students_screen.dart';
import '../features/drivers/drivers_screen.dart';
import '../features/buses/buses_screen.dart';
import '../features/routes_stops/routes_stops_screen.dart';
import '../features/trips/trips_screen.dart';
import '../features/payments/payments_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/qr_print/qr_print_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final isLoggingIn = state.uri.path == '/login';
      final isAuthenticated = authState.isAuthenticated;

      if (!isAuthenticated && !isLoggingIn) {
        return '/login';
      }
      if (isAuthenticated && isLoggingIn) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AdminShell(
            currentRoute: state.uri.path,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/students',
            builder: (context, state) => const StudentsScreen(),
          ),
          GoRoute(
            path: '/drivers',
            builder: (context, state) => const DriversScreen(),
          ),
          GoRoute(
            path: '/buses',
            builder: (context, state) => const BusesScreen(),
          ),
          GoRoute(
            path: '/routes',
            builder: (context, state) => const RoutesStopsScreen(),
          ),
          GoRoute(
            path: '/trips',
            builder: (context, state) => const TripsScreen(),
          ),
          GoRoute(
            path: '/payments',
            builder: (context, state) => const PaymentsScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/qr-print',
            builder: (context, state) => const QrPrintScreen(),
          ),
        ],
      ),
    ],
  );
});
