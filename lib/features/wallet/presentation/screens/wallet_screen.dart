import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../data/models/transaction_item.dart';
import '../providers/wallet_provider.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);
    final txAsync     = ref.watch(walletTransactionsProvider);
    final theme       = Theme.of(context);
    const navy        = Color(0xFF1A3A6B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(walletProvider);
              ref.invalidate(walletTransactionsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(walletProvider);
          ref.invalidate(walletTransactionsProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            // ── Balance card ─────────────────────────────────────────────
            walletAsync.when(
              loading: () => const _BalanceSkeleton(),
              error: (e, _) => _ErrorCard(
                  message: 'Could not load wallet',
                  onRetry: () => ref.invalidate(walletProvider)),
              data: (w) => Container(
                decoration: BoxDecoration(
                  color: navy,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: navy.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.account_balance_wallet_rounded,
                          color: Colors.white70, size: 18),
                      SizedBox(width: 8),
                      Text('Wallet Balance',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12,
                              letterSpacing: 1)),
                    ]),
                    const SizedBox(height: 12),
                    Text(
                      'LKR ${w.balance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: w.isActive
                            ? Colors.green.withValues(alpha: 0.25)
                            : Colors.red.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(w.status,
                          style: TextStyle(
                            color: w.isActive
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Add Money button ─────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.addMoney),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Money'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 24),

            // ── Transactions ─────────────────────────────────────────────
            Text('Recent Transactions', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            txAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorCard(
                  message: 'Could not load transactions',
                  onRetry: () => ref.invalidate(walletTransactionsProvider)),
              data: (items) {
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text('No transactions yet',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }
                return Column(
                  children: items.map((t) => _TxCard(t: t)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Transaction card ──────────────────────────────────────────────────────────

class _TxCard extends StatelessWidget {
  const _TxCard({required this.t});
  final TransactionItem t;

  static final _dateFmt = DateFormat('d MMM  HH:mm');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    DateTime? dt;
    try { dt = DateTime.parse(t.createdAt).toLocal(); } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: t.isCredit
              ? Colors.green.withValues(alpha: 0.12)
              : Colors.red.withValues(alpha: 0.12),
          child: Icon(
            t.isCredit
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            color: t.isCredit ? Colors.green.shade700 : Colors.red.shade700,
            size: 18,
          ),
        ),
        title: Text(
          t.description ?? t.type,
          style: theme.textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: dt != null
            ? Text(_dateFmt.format(dt),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontSize: 12, color: Colors.grey.shade500))
            : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${t.isCredit ? '+' : '-'} LKR ${t.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: t.isCredit
                    ? Colors.green.shade700
                    : Colors.red.shade700,
              ),
            ),
            Text(
              'LKR ${t.balanceAfter.toStringAsFixed(2)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _BalanceSkeleton extends StatelessWidget {
  const _BalanceSkeleton();
  @override
  Widget build(BuildContext context) => Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading:
              const Icon(Icons.error_outline_rounded, color: Colors.red),
          title: Text(message),
          trailing: TextButton(
              onPressed: onRetry, child: const Text('Retry')),
        ),
      );
}
