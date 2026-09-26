import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/router/app_router.dart';
import '../../data/wallet_repository.dart';
import '../providers/wallet_provider.dart';

/// Opens the payment gateway checkout URL in a WebView.
/// After the gateway redirects back, polls the backend for verified status.
///
/// Security: the wallet is NEVER credited locally based on what the WebView
/// returns. Only a server-confirmed SUCCESS triggers a UI update.
class PaymentWebViewScreen extends ConsumerStatefulWidget {
  const PaymentWebViewScreen({
    super.key,
    required this.paymentId,
    required this.checkoutUrl,
    required this.amount,
  });

  final int    paymentId;
  final String checkoutUrl;
  final double amount;

  @override
  ConsumerState<PaymentWebViewScreen> createState() =>
      _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState
    extends ConsumerState<PaymentWebViewScreen> {
  late final WebViewController _wvc;
  bool _isPolling = false;
  String? _pollMessage;

  // Base URL of our own backend (not the gateway) — used to detect the return redirect
  static String get _backendHost => Uri.parse(AppConfig.baseUrl).host;

  @override
  void initState() {
    super.initState();

    // Resolve the actual URL to load:
    // - If it starts with '/' it is a local path (mock gateway) → prepend baseUrl
    // - Otherwise it is an absolute URL (real gateway)
    final rawUrl = widget.checkoutUrl;
    final urlToLoad = rawUrl.startsWith('/')
        ? '${AppConfig.baseUrl}$rawUrl'
        : rawUrl;

    _wvc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) {
          // Detect when the gateway redirects back to our backend return URL
          final uri = Uri.tryParse(req.url);
          if (uri != null &&
              (uri.host == _backendHost || uri.host.isEmpty) &&
              uri.path.contains('/api/payment/')) {
            // Gateway has finished — poll backend for verified status
            _pollStatus();
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(urlToLoad));
  }

  Future<void> _pollStatus() async {
    if (_isPolling) return;
    setState(() {
      _isPolling   = true;
      _pollMessage = 'Verifying payment…';
    });

    // Poll with back-off — webhook may arrive slightly after redirect
    for (int attempt = 1; attempt <= 6; attempt++) {
      await Future.delayed(Duration(seconds: attempt));
      try {
        final status = await ref
            .read(walletRepositoryProvider)
            .pollPaymentStatus(widget.paymentId);

        if (!mounted) return;

        if (status.isSuccess) {
          // Server confirmed — invalidate wallet cache and show success
          ref.invalidate(walletProvider);
          ref.invalidate(walletTransactionsProvider);
          if (!mounted) return;
          context.pushReplacement(AppRoutes.paymentResult, extra: {
            'success': true,
            'amount':  widget.amount,
          });
          return;
        }
        // Still PENDING — keep polling
        setState(() => _pollMessage =
            'Waiting for payment confirmation (attempt $attempt)…');
      } catch (_) {
        // Ignore transient errors during polling
      }
    }

    // Polling exhausted — show inconclusive result; user can check wallet later
    if (!mounted) return;
    context.pushReplacement(AppRoutes.paymentResult, extra: {
      'success': false,
      'amount':  widget.amount,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pay LKR ${widget.amount.toStringAsFixed(2)}'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _wvc),
          if (_isPolling)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(_pollMessage ?? 'Verifying payment…',
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
