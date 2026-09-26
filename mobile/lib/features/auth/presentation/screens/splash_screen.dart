import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Kick off auth check — the router redirect and listener handle navigation
    Future.microtask(() async {
      try {
        await ref.read(authProvider.notifier).checkAuthStatus();
      } catch (e) {
        debugPrint('[SplashScreen] Auth check notice: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (!mounted) return;
      if (next.status == AuthStatus.authenticated) {
        final target = next.role == 'DRIVER'
            ? AppRoutes.driverDashboard
            : AppRoutes.studentDashboard;
        context.go(target);
      } else if (next.status == AuthStatus.unauthenticated) {
        context.go(AppRoutes.login);
      }
    });

    final authState = ref.watch(authProvider);
    if (authState.status == AuthStatus.authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final target = authState.role == 'DRIVER'
              ? AppRoutes.driverDashboard
              : AppRoutes.studentDashboard;
          context.go(target);
        }
      });
    } else if (authState.status == AuthStatus.unauthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go(AppRoutes.login);
        }
      });
    }

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo placeholder
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_bus_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'University Shuttle',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Smart campus transport',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 64),
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
