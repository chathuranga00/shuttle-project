import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../data/models/pass_status_response.dart';
import '../../data/pass_repository.dart';
import '../providers/pass_provider.dart';

/// Monthly Pass screen — shows current status, validity dates, price,
/// and a buy button that calls POST /api/monthly-pass/purchase.
class MonthlyPassScreen extends ConsumerStatefulWidget {
  const MonthlyPassScreen({super.key});

  @override
  ConsumerState<MonthlyPassScreen> createState() => _MonthlyPassScreenState();
}

class _MonthlyPassScreenState extends ConsumerState<MonthlyPassScreen> {
  bool _isPurchasing = false;

  Future<void> _purchase() async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      _showSnack(
        'Live connection required to purchase monthly pass. Offline purchase is disabled.',
        success: false,
      );
      return;
    }

    setState(() => _isPurchasing = true);
    try {
      await ref.read(passRepositoryProvider).purchase();
      if (!mounted) return;
      ref.invalidate(passStatusProvider);
      _showSnack('Monthly pass purchased successfully!', success: true);
    } catch (e) {
      if (!mounted) return;
      _showSnack(_extractMessage(e), success: false);
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  String _extractMessage(Object e) {
    final s = e.toString();
    if (s.contains(': ')) return s.substring(s.lastIndexOf(': ') + 2);
    if (s.startsWith('Exception: ')) return s.substring(11);
    return s;
  }

  void _showSnack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(passStatusProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Pass'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(passStatusProvider),
          ),
        ],
      ),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('Could not load pass status',
                  style: theme.textTheme.titleMedium),
              TextButton.icon(
                onPressed: () => ref.invalidate(passStatusProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (pass) => _PassBody(
          pass: pass,
          isPurchasing: _isPurchasing,
          onPurchase: _purchase,
        ),
      ),
    );
  }
}

// ── Pass body ─────────────────────────────────────────────────────────────────

class _PassBody extends StatelessWidget {
  const _PassBody({
    required this.pass,
    required this.isPurchasing,
    required this.onPurchase,
  });

  final PassStatusResponse pass;
  final bool isPurchasing;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Status card ──────────────────────────────────────────────
          _PassStatusCard(pass: pass),
          const SizedBox(height: 24),

          // ── Price tile ───────────────────────────────────────────────
          Container(
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
            child: Row(
              children: [
                const Icon(Icons.payments_rounded, color: Color(0xFF1A3A6B)),
                const SizedBox(width: 12),
                Text('Monthly pass price', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(
                  'LKR ${pass.nextPurchasePrice.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A3A6B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Text(
              'A monthly pass gives you unlimited boarding on all shuttle '
              'routes for 30 days with zero fare per trip.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 32),

          // ── Buy / active banner ──────────────────────────────────────
          if (pass.isActive && pass.coveringToday)
            const _ActivePassBanner()
          else
            ElevatedButton.icon(
              onPressed: isPurchasing ? null : onPurchase,
              icon: isPurchasing
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.confirmation_num_rounded),
              label: Text(isPurchasing ? 'Purchasing…' : 'Buy Monthly Pass'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Status card ───────────────────────────────────────────────────────────────

class _PassStatusCard extends StatelessWidget {
  const _PassStatusCard({required this.pass});
  final PassStatusResponse pass;

  static const _navy = Color(0xFF1A3A6B);

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (pass.status) {
      'ACTIVE'    => Colors.green,
      'PENDING'   => Colors.orange,
      'EXPIRED'   => Colors.red,
      'CANCELLED' => Colors.grey,
      _           => Colors.grey,
    };

    return Container(
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
              const Icon(Icons.confirmation_num_rounded,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              const Text('Monthly Pass',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: statusColor.shade300, width: 0.8),
                ),
                child: Text(
                  pass.status,
                  style: TextStyle(
                    color: statusColor.shade300,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Validity / no-pass content
          if (pass.hasPass && pass.validFrom != null) ...[
            Text(
              '${pass.validFrom}  →  ${pass.validTo}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (pass.coveringToday)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: Colors.greenAccent, size: 14),
                    SizedBox(width: 6),
                    Text('Active — boarding is FREE today',
                        style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              )
            else if (pass.isActive)
              const Text('Pass active but not covering today',
                  style: TextStyle(color: Colors.white60, fontSize: 13)),
          ] else ...[
            const Text(
              'No active pass',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text('Purchase a pass to board for free',
                style: TextStyle(color: Colors.white60, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

// ── Active-pass confirmation banner ──────────────────────────────────────────

class _ActivePassBanner extends StatelessWidget {
  const _ActivePassBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You have an active pass',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                SizedBox(height: 2),
                Text('Boarding is free for all trips this month.',
                    style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
