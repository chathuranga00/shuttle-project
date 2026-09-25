import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import 'dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
              const SizedBox(height: 12),
              Text(
                'Failed to load dashboard metrics: $err',
                style: const TextStyle(color: AppTheme.danger),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.refresh(dashboardProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operations Overview',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Real-time metrics, active transit monitoring, and quick administrative tasks',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: () => ref.refresh(dashboardProvider),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh Data'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // KPI Grid
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _MetricCard(
                    title: 'Total Students',
                    value: '${data.totalStudents}',
                    subtitle: 'Registered accounts',
                    icon: Icons.school_outlined,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF2563EB),
                    onTap: () => context.go('/students'),
                  ),
                  _MetricCard(
                    title: 'Active Buses',
                    value: '${data.totalBuses}',
                    subtitle: 'Fleet inventory',
                    icon: Icons.directions_bus_outlined,
                    iconBg: const Color(0xFFF0FDF4),
                    iconColor: const Color(0xFF16A34A),
                    onTap: () => context.go('/buses'),
                  ),
                  _MetricCard(
                    title: 'Total Drivers',
                    value: '${data.totalDrivers}',
                    subtitle: 'Staff licensed',
                    icon: Icons.badge_outlined,
                    iconBg: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFFD97706),
                    onTap: () => context.go('/drivers'),
                  ),
                  _MetricCard(
                    title: 'Active Trips',
                    value: '${data.activeTrips}',
                    subtitle: 'Currently running',
                    icon: Icons.departure_board_outlined,
                    iconBg: const Color(0xFFF3E8FF),
                    iconColor: const Color(0xFF9333EA),
                    isLive: data.activeTrips > 0,
                    onTap: () => context.go('/trips'),
                  ),
                  _MetricCard(
                    title: "Today's Passengers",
                    value: '${data.todayPassengers}',
                    subtitle: 'Boardings recorded today',
                    icon: Icons.groups_outlined,
                    iconBg: const Color(0xFFECFEFF),
                    iconColor: const Color(0xFF0891B2),
                    onTap: () => context.go('/reports'),
                  ),
                  _MetricCard(
                    title: "Today's Revenue",
                    value: Formatters.formatCurrency(data.todayRevenue),
                    subtitle: 'Cashless & online top-ups',
                    icon: Icons.payments_outlined,
                    iconBg: const Color(0xFFDCFCE7),
                    iconColor: const Color(0xFF15803D),
                    onTap: () => context.go('/payments'),
                  ),
                  _MetricCard(
                    title: 'Monthly Passes',
                    value: '${data.activeMonthlyPasses}',
                    subtitle: 'Active unexpired passes',
                    icon: Icons.confirmation_number_outlined,
                    iconBg: const Color(0xFFFCE7F3),
                    iconColor: const Color(0xFFDB2777),
                    onTap: () => context.go('/reports'),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Quick Actions Bar
              const Text(
                'Quick Administrative Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _QuickActionCard(
                    title: 'Manage Students',
                    description: 'Search, view details, activate or suspend student access',
                    icon: Icons.people_outline,
                    buttonText: 'View Students',
                    onTap: () => context.go('/students'),
                  ),
                  _QuickActionCard(
                    title: 'Schedule a Trip',
                    description: 'Assign route, driver and bus to schedule a new transit run',
                    icon: Icons.add_circle_outline,
                    buttonText: 'Trips Manager',
                    onTap: () => context.go('/trips'),
                  ),
                  _QuickActionCard(
                    title: 'Print Stop QR Codes',
                    description: 'Generate high-resolution printable QR cards for physical stops',
                    icon: Icons.print_outlined,
                    buttonText: 'Print QR Codes',
                    onTap: () => context.go('/qr-print'),
                  ),
                  _QuickActionCard(
                    title: 'Analytics & Reports',
                    description: 'Export passenger, revenue, and route usage reports in CSV',
                    icon: Icons.download_outlined,
                    buttonText: 'Generate Reports',
                    onTap: () => context.go('/reports'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final bool isLive;
  final VoidCallback onTap;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    this.isLive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                if (isLive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: AppTheme.success),
                        SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: AppTheme.success,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String buttonText;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              child: Text(buttonText, style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
