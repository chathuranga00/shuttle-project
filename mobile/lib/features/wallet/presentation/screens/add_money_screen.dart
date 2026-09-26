import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../data/wallet_repository.dart';

/// Amount selection screen. Shows preset choices and a custom entry.
/// On confirm, calls POST /api/wallet/top-up and navigates to the WebView.
class AddMoneyScreen extends ConsumerStatefulWidget {
  const AddMoneyScreen({super.key});

  @override
  ConsumerState<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends ConsumerState<AddMoneyScreen> {
  static const _presets = [500.0, 1000.0, 2000.0, 5000.0];

  double? _selected;
  final _customCtrl = TextEditingController();
  bool _isCustom    = false;
  bool _isLoading   = false;

  double? get _amount {
    if (_isCustom) {
      return double.tryParse(_customCtrl.text.trim());
    }
    return _selected;
  }

  Future<void> _proceed() async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
          'Live internet connection required for wallet top-up. Offline payments are disabled.',
        ),
        backgroundColor: Colors.red.shade700,
      ));
      return;
    }

    final amount = _amount;
    if (amount == null || amount < 50) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Minimum top-up is LKR 50.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ref.read(walletRepositoryProvider).topUp(amount);
      if (!mounted) return;
      // Navigate to WebView — do NOT credit locally
      context.push(AppRoutes.paymentWebView, extra: {
        'paymentId':   response.paymentId,
        'checkoutUrl': response.checkoutUrl,
        'amount':      amount,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_extractMsg(e)),
          backgroundColor: Colors.red.shade700));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _extractMsg(Object e) {
    final s = e.toString();
    if (s.contains(': ')) return s.substring(s.lastIndexOf(': ') + 2);
    return s;
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Money')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Select amount', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),

            // ── Preset chips ────────────────────────────────────────────
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _presets.map((p) {
                final sel = !_isCustom && _selected == p;
                return ChoiceChip(
                  label: Text('LKR ${p.toStringAsFixed(0)}'),
                  selected: sel,
                  onSelected: (_) => setState(() {
                    _selected = p;
                    _isCustom = false;
                    _customCtrl.clear();
                  }),
                  selectedColor: const Color(0xFF1A3A6B),
                  labelStyle: TextStyle(
                    color: sel ? Colors.white : null,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Custom amount ───────────────────────────────────────────
            Row(children: [
              Checkbox(
                value: _isCustom,
                onChanged: (v) => setState(() {
                  _isCustom = v ?? false;
                  if (_isCustom) _selected = null;
                }),
              ),
              const Text('Enter custom amount'),
            ]),
            if (_isCustom) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount (LKR)',
                  prefixText: 'LKR ',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 32),

            // ── Summary ─────────────────────────────────────────────────
            if (_amount != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You will be taken to the payment gateway to '
                      'complete LKR ${_amount!.toStringAsFixed(2)}. '
                      'Your wallet is credited only after the payment '
                      'is verified server-side.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ]),
              ),
            const SizedBox(height: 24),

            // ── Proceed button ───────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: (_amount == null || _isLoading) ? null : _proceed,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.payment_rounded),
              label: Text(_isLoading ? 'Preparing…' : 'Proceed to Payment'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
