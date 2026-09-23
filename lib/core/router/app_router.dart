import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/driver/presentation/screens/driver_dashboard_screen.dart';
import '../../features/student/presentation/screens/student_dashboard_screen.dart';

// ── Route names ───────────────────────────────────────────────────────────────
class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const studentDashboard = '/student';
  static const driverDashboard = '/driver';
}

// ── Router provider ───────────────────────────────────────────────────────────
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _AuthChangeNotifier(ref),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isOnSplash = state.matchedLocation == AppRoutes.splash;
      final isOnAuth = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.forgotPassword;

      // Still initialising — stay on splash
      if (authState.status == AuthStatus.unknown) {
        return isOnSplash ? null : AppRoutes.splash;
      }

      // Not logged in — send to login
      if (authState.status == AuthStatus.unauthenticated) {
        return isOnAuth ? null : AppRoutes.login;
      }

      // Logged in — redirect away from auth screens to the right dashboard
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
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentDashboard,
        builder: (_, __) => const StudentDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.driverDashboard,
        builder: (_, __) => const DriverDashboardScreen(),
      ),
    ],
  );
});

/// Bridges Riverpod state changes to GoRouter's [Listenable] refresh mechanism.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}
