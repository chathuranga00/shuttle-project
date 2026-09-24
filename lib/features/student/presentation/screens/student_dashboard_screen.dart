import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/connectivity_banner.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../boarding/presentation/providers/boarding_provider.dart';
import '../providers/student_provider.dart';

class StudentDashboardScreen extends ConsumerWidget {
  const StudentDashboardScreen({super.key});

  // ── Greeting helper ───────────────────────────────────────────────────────
  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(studentProfileProvider);
    final cardAsync    = ref.watch(studentCardProvider);
    final theme        = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shuttle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_rounded),
            tooltip: 'My Profile',
            onPressed: () => context.push(AppRoutes.profile),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: ConnectivityBanner(child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(studentProfileProvider);
          ref.invalidate(studentCardProvider);
          ref.invalidate(boardingHistoryProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Greeting section ─────────────────────────────────
                  profileAsync.when(
                    loading: () => _GreetingCard(
                      greeting: _greeting(),
                      name: '…',
                      initials: '…',
                    ),
                    error: (_, __) => _GreetingCard(
                      greeting: _greeting(),
                      name: 'Student',
                      initials: 'S',
                    ),
                    data: (profile) => _GreetingCard(
                      greeting: _greeting(),
                      name: profile.firstName,
                      initials: profile.initials,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Card status row ──────────────────────────────────
                  cardAsync.when(
                    loading: () => const _StatusRowSkeleton(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (card) => _CardStatusRow(
                      cardStatus: card.cardStatus,
                      cardId: card.cardId,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Info cards row ───────────────────────────────────
                  cardAsync.when(
                    loading: () => const _InfoRowSkeleton(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (card) => Row(
                      children: [
                        Expanded(
                          child: _InfoTile(
                            icon: Icons.account_balance_wallet_rounded,
                            label: 'Wallet Balance',
                            value: 'LKR ${card.wallet.balance}',
                            iconColor: const Color(0xFF1A3A6B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InfoTile(
                            icon: Icons.confirmation_num_rounded,
                            label: 'Monthly Pass',
                            value: card.monthlyPassStatus,
                            iconColor: card.hasActivePass
                                ? Colors.green.shade700
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── SCAN BOARDING QR button ──────────────────────
                  _ScanBoardingButton(
                    onPressed: () => context.push(AppRoutes.qrScanner),
                  ),
                  const SizedBox(height: 24),

                  // ── My Bus Card tile ─────────────────────────────────
                  Text('Quick Actions', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _ActionTile(
                    icon: Icons.credit_card_rounded,
                    label: 'My Bus Card',
                    subtitle: 'View card, QR code & wallet balance',
                    onTap: () => context.push(AppRoutes.busCard),
                  ),
                  _ActionTile(
                    icon: Icons.route_rounded,
                    label: 'Find a Route',
                    subtitle: 'Browse available shuttle routes & fares',
                    onTap: () => context.push(AppRoutes.busRoutes),
                  ),

                  // ── Recent journeys (real data) ───────────────────────
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Journeys',
                          style: theme.textTheme.titleLarge),
                      TextButton(
                        onPressed: () =>
                            context.push(AppRoutes.travelHistory),
                        child: const Text('View all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _RecentJourneys(),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      )),  // ConnectivityBanner closes here
    );
  }
}

// ── Greeting card ─────────────────────────────────────────────────────────────
class _GreetingCard extends StatelessWidget {
  const _GreetingCard({
    required this.greeting,
    required this.name,
    required this.initials,
  });

  final String greeting;
  final String name;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFF5A623),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, $name!',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Here's your travel summary",
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card status row ───────────────────────────────────────────────────────────
class _CardStatusRow extends StatelessWidget {
  const _CardStatusRow({required this.cardStatus, required this.cardId});
  final String cardStatus;
  final String cardId;

  @override
  Widget build(BuildContext context) {
    final isActive = cardStatus == 'ACTIVE';
    final shortId  = cardId.length > 8 ? cardId.substring(cardId.length - 8) : cardId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.credit_card_rounded, color: Color(0xFF1A3A6B)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '···$shortId',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          _StatusPill(isActive: isActive),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? Colors.green.shade400 : Colors.red.shade400,
        ),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(
          color: isActive ? Colors.green.shade700 : Colors.red.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Info tile ─────────────────────────────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: iconColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Action tile ───────────────────────────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 26),
        ),
        title: Text(label, style: theme.textTheme.titleMedium),
        subtitle: Text(subtitle, style: theme.textTheme.bodyMedium),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

// ── Skeleton placeholders ─────────────────────────────────────────────────────
class _StatusRowSkeleton extends StatelessWidget {
  const _StatusRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(child: LinearProgressIndicator()),
    );
  }
}

class _InfoRowSkeleton extends StatelessWidget {
  const _InfoRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Scan Boarding QR button ───────────────────────────────────────────────────
class _ScanBoardingButton extends ConsumerWidget {
  const _ScanBoardingButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    const navy = Color(0xFF1A3A6B);

    return ElevatedButton.icon(
      onPressed: isOnline ? onPressed : null,
      icon: const Icon(Icons.qr_code_scanner_rounded),
      label: Text(isOnline ? 'SCAN BOARDING QR' : 'OFFLINE — SCAN DISABLED'),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        backgroundColor: navy,
        foregroundColor: Colors.white,
        disabledBackgroundColor: navy.withValues(alpha: 0.35),
        disabledForegroundColor: Colors.white54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Recent journeys (real data, up to 3 items) ────────────────────────────────
class _RecentJourneys extends ConsumerWidget {
  const _RecentJourneys();

  static final _dateFmt = DateFormat('d MMM  HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(boardingHistoryProvider);
    final theme = Theme.of(context);

    return historyAsync.when(
      loading: () => const Center(
          child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: CircularProgressIndicator(),
      )),
      error: (_, __) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          title: const Text('Could not load journeys'),
          trailing: TextButton(
            onPressed: () => ref.invalidate(boardingHistoryProvider),
            child: const Text('Retry'),
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.history_rounded,
                    color: theme.colorScheme.primary),
              ),
              title: const Text('No recent journeys'),
              subtitle:
                  const Text('Your boarding history will appear here'),
            ),
          );
        }

        final recent = items.take(3).toList();
        return Column(
          children: recent.map((item) {
            final isPaid = item.isPaid;
            DateTime? dt;
            try { dt = DateTime.parse(item.boardedAt).toLocal(); } catch (_) {}

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.directions_bus_rounded,
                      color: theme.colorScheme.primary, size: 22),
                ),
                title: Text(item.routeName,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [
                    item.busStopName,
                    if (dt != null) _dateFmt.format(dt),
                  ].join('  ·  '),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.fareAmount != null
                          ? 'LKR ${item.fareAmount!.toStringAsFixed(2)}'
                          : '—',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isPaid
                              ? Colors.green.shade400
                              : Colors.orange.shade400,
                          width: 0.7,
                        ),
                      ),
                      child: Text(
                        item.paymentStatus,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isPaid
                              ? Colors.green.shade700
                              : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
