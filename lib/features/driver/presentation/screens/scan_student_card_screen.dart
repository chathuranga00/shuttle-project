import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/providers/connectivity_provider.dart';
import '../../data/models/card_verification_result.dart';
import '../providers/driver_providers.dart';

/// Screen allowing the driver to manually scan or check a student's virtual bus card.
/// Calls POST /api/cards/verify with the scanned QR token.
/// Spec Section 18: High contrast result display with big touch targets.
class ScanStudentCardScreen extends ConsumerStatefulWidget {
  const ScanStudentCardScreen({super.key});

  @override
  ConsumerState<ScanStudentCardScreen> createState() =>
      _ScanStudentCardScreenState();
}

class _ScanStudentCardScreenState extends ConsumerState<ScanStudentCardScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
  );

  final TextEditingController _manualController = TextEditingController();

  bool _isVerifying = false;
  CardVerificationResult? _lastResult;
  String? _verificationError;
  bool _showManualInput = false;

  @override
  void dispose() {
    _scannerController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isVerifying || _lastResult != null) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null || barcode!.rawValue!.isEmpty) return;

    await _verifyToken(barcode.rawValue!);
  }

  Future<void> _verifyToken(String token) async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      setState(() {
        _isVerifying = false;
        _verificationError =
            'Live server connection required to verify student cards. Offline verification is disabled.';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _verificationError = null;
    });

    try {
      await _scannerController.stop();
    } catch (_) {}

    final result = await ref
        .read(driverActionControllerProvider.notifier)
        .verifyCard(token.trim());

    if (!mounted) return;

    setState(() {
      _isVerifying = false;
      if (result != null) {
        _lastResult = result;
      } else {
        _verificationError =
            'Invalid card token or card not found. Please verify with student.';
      }
    });
  }

  void _resetScanner() {
    setState(() {
      _lastResult = null;
      _verificationError = null;
      _isVerifying = false;
    });
    _manualController.clear();
    try {
      _scannerController.start();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Verify Student Card'),
        actions: [
          IconButton(
            icon: Icon(
              _showManualInput ? Icons.qr_code_scanner_rounded : Icons.keyboard_rounded,
            ),
            tooltip: _showManualInput ? 'Camera Scanner' : 'Manual Entry',
            onPressed: () {
              setState(() {
                _showManualInput = !_showManualInput;
                if (!_showManualInput && _lastResult == null) {
                  _scannerController.start();
                }
              });
            },
          ),
          if (!_showManualInput)
            IconButton(
              icon: const Icon(Icons.flash_on_rounded),
              tooltip: 'Toggle Flash',
              onPressed: () => _scannerController.toggleTorch(),
            ),
        ],
      ),
      body: Stack(
        children: [
          // ── Scanner or Manual View ──────────────────────────────────
          if (_showManualInput)
            _buildManualInputView()
          else
            _buildCameraView(),

          // ── Loading Overlay ─────────────────────────────────────────
          if (_isVerifying)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.amber),
                    SizedBox(height: 16),
                    Text(
                      'Verifying Bus Card...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Result Sheet / Dialog Overlay ───────────────────────────
          if (_lastResult != null)
            _buildResultOverlay(_lastResult!)
          else if (_verificationError != null)
            _buildErrorOverlay(_verificationError!),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: _handleBarcode,
        ),
        Center(
          child: Container(
            width: 270,
            height: 270,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        Positioned(
          bottom: 30,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Align student virtual bus card QR inside the box to verify membership status.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualInputView() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manual Card Check',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the student card token or raw payload to verify validity and pass status.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _manualController,
            decoration: InputDecoration(
              labelText: 'QR Token / Card Payload',
              hintText: 'Paste or type card token',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                final token = _manualController.text.trim();
                if (token.isNotEmpty) {
                  _verifyToken(token);
                }
              },
              icon: const Icon(Icons.verified_user_rounded),
              label: const Text('Verify Card'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultOverlay(CardVerificationResult result) {
    final isValid = result.isValid;
    final hasPass = result.hasActivePass;

    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor:
                    isValid ? Colors.green.shade100 : Colors.red.shade100,
                child: Icon(
                  isValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 52,
                  color: isValid ? Colors.green.shade800 : Colors.red.shade800,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isValid ? 'VALID BUS CARD' : 'INVALID / INACTIVE',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isValid ? Colors.green.shade900 : Colors.red.shade900,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              _InfoRow(label: 'Student Name', value: result.studentName),
              const SizedBox(height: 8),
              _InfoRow(label: 'Card Identifier', value: result.cardId),
              const SizedBox(height: 8),
              _InfoRow(label: 'Card Status', value: result.cardStatus),
              const SizedBox(height: 8),

              // ── Pass status pill ──────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Pass Status:',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasPass
                          ? Colors.teal.shade100
                          : Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      hasPass ? 'ACTIVE MONTHLY PASS' : 'PAY-PER-TRIP',
                      style: TextStyle(
                        color: hasPass
                            ? Colors.teal.shade900
                            : Colors.brown.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56, // Big button per spec section 18
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _resetScanner,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text(
                    'SCAN ANOTHER CARD',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorOverlay(String error) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.red.shade100,
                child: Icon(Icons.error_outline_rounded,
                    size: 48, color: Colors.red.shade800),
              ),
              const SizedBox(height: 16),
              const Text(
                'Verification Failed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _resetScanner,
                  child: const Text('Try Again'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
