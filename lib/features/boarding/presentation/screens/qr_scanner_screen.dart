import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../data/boarding_repository.dart';

/// Fullscreen QR scanner. Scans a bus-stop signed QR payload, calls
/// POST /api/boarding/validate, then navigates to the confirmation screen.
///
/// Security: no manual text entry is allowed — the stop identity comes
/// exclusively from the signed QR payload.
class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final payload = barcode!.rawValue!;

    // Only process if online
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      setState(() => _errorMessage =
          'You are offline. Please connect to the internet to board.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    await _controller.stop();

    try {
      final result = await ref
          .read(boardingRepositoryProvider)
          .validate(stopQrPayload: payload);

      if (!mounted) return;

      if (result.valid) {
        context.push(AppRoutes.boardingConfirm, extra: {
          'payload': payload,
          'validation': result,
        });
      } else {
        // Backend returned valid=false with a friendly message
        setState(() {
          _errorMessage = result.message;
          _isProcessing = false;
        });
        await _controller.start();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not validate QR. Please try again.';
        _isProcessing = false;
      });
      await _controller.start();
    }
  }

  void _retry() {
    setState(() {
      _errorMessage = null;
      _isProcessing = false;
    });
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan Stop QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            tooltip: 'Toggle torch',
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Camera view ──────────────────────────────────────────────
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // ── Viewfinder overlay ───────────────────────────────────────
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isProcessing
                      ? Colors.amber
                      : (_errorMessage != null ? Colors.red : Colors.white),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // ── Instruction label ────────────────────────────────────────
          Positioned(
            bottom: 100,
            left: 24,
            right: 24,
            child: Column(
              children: [
                if (_isProcessing) ...[
                  const CircularProgressIndicator(color: Colors.amber),
                  const SizedBox(height: 12),
                  const Text(
                    'Validating…',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ] else if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Colors.white, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _retry,
                          child: const Text('Scan Again',
                              style: TextStyle(color: Colors.amber)),
                        ),
                      ],
                    ),
                  ),
                ] else if (!isOnline) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade800.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_rounded,
                            color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text('Offline — boarding disabled',
                            style:
                                TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Point at the bus stop QR code to board',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
