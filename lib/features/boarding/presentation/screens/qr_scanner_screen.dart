import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../data/boarding_repository.dart';

/// Fullscreen QR scanner.
/// 1. Requests location permission (with explanation).
/// 2. Scans a bus-stop signed QR payload.
/// 3. Calls POST /api/boarding/validate (with GPS coordinates).
/// 4. Navigates to the confirmation screen on success.
///
/// Security: no manual text entry — stop identity comes from the signed QR only.
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
  bool _permissionPermanentlyDenied = false;
  bool _locationServiceDisabled     = false;

  /// Cached position from the most recent location request.
  Position? _position;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Location handling ─────────────────────────────────────────────────────

  Future<bool> _ensureLocation() async {
    final result = await requestLocation();
    switch (result) {
      case LocationAvailable(:final position):
        _position = position;
        return true;
      case LocationPermissionDenied(:final permanent):
        setState(() {
          _permissionPermanentlyDenied = permanent;
          _errorMessage = permanent
              ? 'Location permission was denied. Please enable it in Settings '
                'to use GPS verification.'
              : 'Location permission denied. Scanning will continue without GPS.';
        });
        // Soft-deny: allow scan to proceed without GPS (server may skip check)
        return true;
      case LocationServiceDisabled():
        setState(() {
          _locationServiceDisabled = true;
          _errorMessage = 'Location services are off. '
              'Enable GPS to use proximity verification.';
        });
        // Soft: allow scan without GPS
        return true;
      case LocationError(:final message):
        setState(() => _errorMessage = message);
        return true; // allow scan without GPS
    }
  }

  // ── Scan handling ─────────────────────────────────────────────────────────

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final payload = barcode!.rawValue!;

    // Online check
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      setState(() => _errorMessage =
          'You are offline. Please connect to the internet to board.');
      return;
    }

    setState(() {
      _isProcessing  = true;
      _errorMessage  = null;
    });
    await _controller.stop();

    // Acquire location (non-blocking — will use cached or null)
    await _ensureLocation();

    try {
      final result = await ref.read(boardingRepositoryProvider).validate(
            stopQrPayload: payload,
            latitude:       _position?.latitude,
            longitude:      _position?.longitude,
            accuracyMeters: _position?.accuracy,
          );

      if (!mounted) return;

      if (result.valid) {
        context.push(AppRoutes.boardingConfirm, extra: {
          'payload':    payload,
          'validation': result,
          'position':   _position,
        });
      } else {
        setState(() {
          _errorMessage  = result.message;
          _isProcessing  = false;
        });
        await _controller.start();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage  = 'Could not validate QR. Please try again.';
        _isProcessing  = false;
      });
      await _controller.start();
    }
  }

  void _retry() {
    setState(() {
      _errorMessage              = null;
      _isProcessing              = false;
      _permissionPermanentlyDenied = false;
      _locationServiceDisabled   = false;
    });
    _controller.start();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
          // ── Camera view ────────────────────────────────────────────
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // ── Viewfinder frame ───────────────────────────────────────
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

          // ── GPS indicator (top-right) ──────────────────────────────
          Positioned(
            top: 12, right: 16,
            child: _position != null
                ? _GpsChip(
                    label: '±${_position!.accuracy.toStringAsFixed(0)} m',
                    color: _position!.accuracy <= 50
                        ? Colors.green
                        : _position!.accuracy <= 100
                            ? Colors.amber
                            : Colors.orange,
                  )
                : const _GpsChip(label: 'GPS off', color: Colors.grey),
          ),

          // ── Bottom status area ─────────────────────────────────────
          Positioned(
            bottom: 80, left: 24, right: 24,
            child: _buildStatusWidget(isOnline),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusWidget(bool isOnline) {
    if (_isProcessing) {
      return const Column(children: [
        CircularProgressIndicator(color: Colors.amber),
        SizedBox(height: 12),
        Text('Validating…',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16)),
      ]);
    }

    if (_errorMessage != null) {
      return _ErrorCard(
        message: _errorMessage!,
        showSettingsButton:
            _permissionPermanentlyDenied || _locationServiceDisabled,
        onSettings: _permissionPermanentlyDenied
            ? openLocationSettings
            : openDeviceLocationSettings,
        onRetry: _retry,
      );
    }

    if (!isOnline) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade800.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Offline — boarding disabled',
                style: TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      );
    }

    return const Text(
      'Point at the bus stop QR code to board',
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.white, fontSize: 15),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _GpsChip extends StatelessWidget {
  const _GpsChip({required this.label, required this.color});
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.onRetry,
    this.showSettingsButton = false,
    this.onSettings,
  });
  final String   message;
  final VoidCallback onRetry;
  final bool     showSettingsButton;
  final Future<void> Function()? onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.white, size: 28),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: onRetry,
                child: const Text('Scan Again',
                    style: TextStyle(color: Colors.amber)),
              ),
              if (showSettingsButton && onSettings != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onSettings,
                  child: const Text('Open Settings',
                      style: TextStyle(color: Colors.white70)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
