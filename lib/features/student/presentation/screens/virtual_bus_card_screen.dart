import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/student_provider.dart';

class VirtualBusCardScreen extends ConsumerStatefulWidget {
  const VirtualBusCardScreen({super.key});

  @override
  ConsumerState<VirtualBusCardScreen> createState() =>
      _VirtualBusCardScreenState();
}

class _VirtualBusCardScreenState extends ConsumerState<VirtualBusCardScreen> {
  Timer? _refreshTimer;
  DateTime _lastRefreshed = DateTime.now();

  // ── Colours ───────────────────────────────────────────────────────────────
  static const _cardGradientStart = Color(0xFF1A3A6B);

  @override
  void initState() {
    super.initState();
    // Auto-refresh every 45 seconds — well within the 60-second token TTL.
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      ref.invalidate(studentCardProvider);
      setState(() => _lastRefreshed = DateTime.now());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _manualRefresh() {
    ref.invalidate(studentCardProvider);
    setState(() => _lastRefreshed = DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final cardAsync    = ref.watch(studentCardProvider);
    final profileAsync = ref.watch(studentProfileProvider);
    final theme        = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bus Card'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh QR',
            onPressed: _manualRefresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _manualRefresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: cardAsync.when(
            loading: () => const SizedBox(
              height: 400,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _ErrorView(message: e.toString(), onRetry: _manualRefresh),
            data: (card) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Hero card ────────────────────────────────────────────
                _HeroCard(
                  cardId:           card.cardId,
                  cardStatus:       card.cardStatus,
                  monthlyPassStatus: card.monthlyPassStatus,
                  profileAsync:     profileAsync,
                ),
                const SizedBox(height: 24),

                // ── QR code ──────────────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: QrImageView(
                          key: ValueKey(card.qrToken),
                          data: card.qrToken,
                          version: QrVersions.auto,
                          size: 220,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: _cardGradientStart,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: _cardGradientStart,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 14,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Text(
                            'QR refreshes every 45 seconds',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last updated: ${_formatTime(_lastRefreshed)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Wallet info ───────────────────────────────────────────
                _InfoCard(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Wallet Balance',
                  value: 'LKR ${card.wallet.balance}',
                  valueColor: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  icon: Icons.confirmation_num_rounded,
                  label: 'Monthly Pass',
                  value: card.monthlyPassStatus,
                  valueColor: card.hasActivePass ? Colors.green.shade700 : Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
}

// ── Hero card widget ───────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.cardId,
    required this.cardStatus,
    required this.monthlyPassStatus,
    required this.profileAsync,
  });

  static const _cardGradientStart = Color(0xFF1A3A6B);
  static const _cardGradientEnd   = Color(0xFF0D2244);
  static const _amber             = Color(0xFFF5A623);

  final String cardId;
  final String cardStatus;
  final String monthlyPassStatus;
  final AsyncValue<dynamic> profileAsync;

  @override
  Widget build(BuildContext context) {
    final isActive = cardStatus == 'ACTIVE';
    final hasPass  = monthlyPassStatus == 'ACTIVE';

    final String displayName = profileAsync.maybeWhen(
      data: (p) => p.fullName as String,
      orElse: () => '—',
    );
    final String displayStudentId = profileAsync.maybeWhen(
      data: (p) => p.studentId as String,
      orElse: () => '—',
    );

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cardGradientStart, _cardGradientEnd],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _cardGradientStart.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Icon(Icons.school_rounded, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              const Text(
                'University Shuttle',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              // Status chip
              _StatusChip(isActive: isActive),
            ],
          ),
          const SizedBox(height: 20),

          // Student name
          Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),

          // Student ID
          Text(
            'ID: $displayStudentId',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),

          // Card ID
          Text(
            'Card: $cardId',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),

          // Monthly pass badge
          if (hasPass)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _amber,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.confirmation_num_rounded, size: 13, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'Monthly Pass Active',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'No Monthly Pass',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withValues(alpha: 0.85)
            : Colors.red.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: Colors.white,
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'ACTIVE' : cardStatusLabel(isActive),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  String cardStatusLabel(bool active) => active ? 'ACTIVE' : 'INACTIVE';
}

// ── Info card widget ──────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1A3A6B), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              'Could not load card data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
