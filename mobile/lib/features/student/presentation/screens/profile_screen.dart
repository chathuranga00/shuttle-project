import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/student_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(studentProfileProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Could not load profile: $e',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => ref.invalidate(studentProfileProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (profile) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Avatar ──────────────────────────────────────────────
              CircleAvatar(
                radius: 48,
                backgroundColor: const Color(0xFFF5A623),
                child: Text(
                  profile.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 32,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Name & email ─────────────────────────────────────────
              Text(profile.fullName, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                profile.email,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF555577),
                ),
              ),
              const SizedBox(height: 24),

              const Divider(),
              const SizedBox(height: 8),

              // ── Info tiles ───────────────────────────────────────────
              _ProfileTile(
                icon: Icons.badge_rounded,
                label: 'Student ID',
                value: profile.studentId,
              ),
              _ProfileTile(
                icon: Icons.school_rounded,
                label: 'Faculty',
                value: profile.faculty,
              ),
              _ProfileTile(
                icon: Icons.calendar_today_rounded,
                label: 'Enrollment Year',
                value: profile.enrollmentYear.toString(),
              ),
              if (profile.phone != null)
                _ProfileTile(
                  icon: Icons.phone_rounded,
                  label: 'Phone',
                  value: profile.phone!,
                ),

              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 24),

              // ── Sign out ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(authProvider.notifier).logout(),
                  icon: const Icon(Icons.logout_rounded,
                      color: Colors.red),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Profile tile ──────────────────────────────────────────────────────────────
class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: Icon(icon, color: const Color(0xFF1A3A6B)),
      title: Text(label, style: theme.textTheme.bodyMedium),
      subtitle: Text(
        value,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
