import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/boarding/data/models/validate_boarding_response.dart';
import '../../features/boarding/presentation/screens/boarding_confirm_screen.dart';
import '../../features/boarding/presentation/screens/boarding_result_screen.dart';
import '../../features/boarding/presentation/screens/qr_scanner_screen.dart';
import '../../features/boarding/presentation/screens/travel_history_screen.dart';
import '../../features/driver/presentation/screens/driver_dashboard_screen.dart';
import '../../features/pass/presentation/screens/monthly_pass_screen.dart';
import '../../features/routes/presentation/screens/bus_routes_screen.dart';
import '../../features/routes/presentation/screens/bus_stops_screen.dart';
import '../../features/student/presentation/screens/profile_screen.dart';
import '../../features/student/presentation/screens/student_dashboard_screen.dart';
import '../../features/student/presentation/screens/virtual_bus_card_screen.dart';
import '../../features/wallet/presentation/screens/add_money_screen.dart';
import '../../features/wallet/presentation/screens/payment_history_screen.dart';
import '../../features/wallet/presentation/screens/payment_result_screen.dart';
import '../../features/wallet/presentation/screens/payment_webview_screen.dart';
import '../../features/wallet/presentation/screens/wallet_screen.dart';

// ── Route name constants ──────────────────────────────────────────────────────
class AppRoutes {
  static const splash            = '/';
  static const login             = '/login';
  static const register          = '/register';
  static const forgotPassword    = '/forgot-password';
  static const studentDashboard  = '/student';
  static const busCard           = '/student/card';
  static const profile           = '/student/profile';
  static const busRoutes         = '/routes';
  static const busStops          = '/routes/stops';
  static const qrScanner         = '/boarding/scan';
  static const boardingConfirm   = '/boarding/confirm';
  static const boardingResult    = '/boarding/result';
  static const travelHistory     = '/boarding/history';
  static const monthlyPass       = '/pass';
  static const wallet            = '/wallet';
  static const addMoney          = '/wallet/add';
  static const paymentWebView    = '/wallet/pay';
  static const paymentResult     = '/wallet/pay/result';
  static const paymentHistory    = '/wallet/payments';
  static const driverDashboard   = '/driver';
}

// ── Router provider ───────────────────────────────────────────────────────────
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _AuthChangeNotifier(ref),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final loc = state.matchedLocation;
      final isOnSplash = loc == AppRoutes.splash;
      final isOnAuth   = loc == AppRoutes.login  ||
          loc == AppRoutes.register ||
          loc == AppRoutes.forgotPassword;

      if (authState.status == AuthStatus.unknown) {
        return isOnSplash ? null : AppRoutes.splash;
      }
      if (authState.status == AuthStatus.unauthenticated) {
        return isOnAuth ? null : AppRoutes.login;
      }
      if (authState.status == AuthStatus.authenticated) {
        if (isOnSplash || isOnAuth) {
          return authState.role == 'DRIVER'
              ? AppRoutes.driverDashboard
              : AppRoutes.studentDashboard;
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash,
          builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.login,
          builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppRoutes.register,
          builder: (_, __) => const RegisterScreen()),
      GoRoute(path: AppRoutes.forgotPassword,
          builder: (_, __) => const ForgotPasswordScreen()),

      // ── Student ──────────────────────────────────────────────────────
      GoRoute(path: AppRoutes.studentDashboard,
          builder: (_, __) => const StudentDashboardScreen()),
      GoRoute(path: AppRoutes.busCard,
          builder: (_, __) => const VirtualBusCardScreen()),
      GoRoute(path: AppRoutes.profile,
          builder: (_, __) => const ProfileScreen()),

      // ── Routes / Stops ───────────────────────────────────────────────
      GoRoute(path: AppRoutes.busRoutes,
          builder: (_, __) => const BusRoutesScreen()),
      GoRoute(
        path: AppRoutes.busStops,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return BusStopsScreen(
            routeId:   extra['routeId']   as int,
            routeName: extra['routeName'] as String,
          );
        },
      ),

      // ── Boarding flow ─────────────────────────────────────────────────
      GoRoute(path: AppRoutes.qrScanner,
          builder: (_, __) => const QrScannerScreen()),

      GoRoute(
        path: AppRoutes.boardingConfirm,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return BoardingConfirmScreen(
            stopQrPayload: extra['payload']    as String,
            validation:    extra['validation'] as ValidateBoardingResponse,
            position:      extra['position'],   // Position? — null when GPS unavailable
          );
        },
      ),

      GoRoute(
        path: AppRoutes.boardingResult,
        builder: (context, state) {
          // extra is either BoardingConfirmResponse (success) or String (error)
          return BoardingResultScreen(result: state.extra!);
        },
      ),

      GoRoute(path: AppRoutes.travelHistory,
          builder: (_, __) => const TravelHistoryScreen()),

      GoRoute(path: AppRoutes.monthlyPass,
          builder: (_, __) => const MonthlyPassScreen()),

      // ── Wallet / Payments ─────────────────────────────────────────────
      GoRoute(path: AppRoutes.wallet,
          builder: (_, __) => const WalletScreen()),
      GoRoute(path: AppRoutes.addMoney,
          builder: (_, __) => const AddMoneyScreen()),
      GoRoute(
        path: AppRoutes.paymentWebView,
        builder: (context, state) {
          final e = state.extra as Map<String, dynamic>;
          return PaymentWebViewScreen(
            paymentId:   e['paymentId']   as int,
            checkoutUrl: e['checkoutUrl'] as String,
            amount:      e['amount']      as double,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.paymentResult,
        builder: (context, state) {
          final e = state.extra as Map<String, dynamic>;
          return PaymentResultScreen(
            success: e['success'] as bool,
            amount:  e['amount']  as double,
          );
        },
      ),
      GoRoute(path: AppRoutes.paymentHistory,
          builder: (_, __) => const PaymentHistoryScreen()),

      // ── Driver ────────────────────────────────────────────────────────
      GoRoute(path: AppRoutes.driverDashboard,
          builder: (_, __) => const DriverDashboardScreen()),
    ],
  );
});

/// Bridges Riverpod state changes to GoRouter's [Listenable] refresh mechanism.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}
