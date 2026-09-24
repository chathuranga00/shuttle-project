import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../data/boarding_repository.dart';
import '../../data/models/validate_boarding_response.dart';
import '../providers/boarding_provider.dart';
/// Shows the boarding preview (stop, route, fare) and a large Confirm button.
/// On confirm, calls POST /api/boarding/confirm.
/// A boarding is never shown as confirmed unless the server returned 200.
class BoardingConfirmScreen extends ConsumerStatefulWidget {
  const BoardingConfirmScreen({
    super.key,
    required this.stopQrPayload,
    required this.validation,
    this.position,
  });

  final String stopQrPayload;
  final ValidateBoardingResponse validation;
  /// GPS position captured at scan time — passed through to confirm call.
  final Position? position;

  @override
  ConsumerState<BoardingConfirmScreen> createState() =>
      _BoardingConfirmScreenState();
}

class _BoardingConfirmScreenState
    extends ConsumerState<BoardingConfirmScreen> {
  bool _isConfirming = false;

  Future<void> _confirm() async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      _showSnack('You are offline. Please connect and try again.',
          isError: true);
      return;
    }

    setState(() => _isConfirming = true);

    // Refresh location at confirm time for highest accuracy
    Position? position = widget.position;
    final locResult = await requestLocation();
    if (locResult is LocationAvailable) {
      position = locResult.position;
    }

    try {
      final result = await ref.read(boardingRepositoryProvider).confirm(
            stopQrPayload: widget.stopQrPayload,
            tripId:         widget.validation.tripId!,
            latitude:       position?.latitude,
            longitude:      position?.longitude,
            accuracyMeters: position?.accuracy,
          );

      if (!mounted) return;

      // Invalidate history so dashboard refreshes
      ref.invalidate(boardingHistoryProvider);

      // Navigate to result screen — only now can we show "confirmed"
      context.pushReplacement(AppRoutes.boardingResult,
          extra: result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isConfirming = false);

      // Use exact backend message if available
      final msg = e is Exception ? e.toString() : 'Boarding failed.';
      context.pushReplacement(AppRoutes.boardingResult,
          extra: msg); // String extra = error
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final v       = widget.validation;
    final isOnline = ref.watch(isOnlineProvider);

    const navy = Color(0xFF1A3A6B);
    const amber = Color(0xFFF5A623);

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Boarding')),
      body: Column(
        children: [
          // ── Offline banner ─────────────────────────────────────────
          if (!isOnline)
            Container(
              color: Colors.red.shade700,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off_rounded,
                      color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'You are offline. Boarding is disabled.',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── VALID status chip ────────────────────────────────
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.shade400),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              color: Colors.green.shade700, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'VALID',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Boarding details card ────────────────────────────
                  Container(
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
                        const Row(
                          children: [
                            Icon(Icons.directions_bus_rounded,
                                color: Colors.white70, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Boarding Details',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  letterSpacing: 1),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _DetailRow(
                          icon: Icons.location_on_rounded,
                          label: 'Stop',
                          value: v.stopName ?? '—',
                        ),
                        const SizedBox(height: 10),
                        _DetailRow(
                          icon: Icons.route_rounded,
                          label: 'Route',
                          value: v.routeName ?? '—',
                        ),
                        const SizedBox(height: 10),
                        _DetailRow(
                          icon: Icons.confirmation_number_rounded,
                          label: 'Trip ID',
                          value: '${v.tripId}',
                        ),
                        const SizedBox(height: 16),
                        // ── Fare chip ──────────────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: amber,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.payments_rounded,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                v.fare != null
                                    ? 'LKR ${v.fare!.toStringAsFixed(2)}'
                                    : 'Fare not set',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Important notice ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: Colors.amber, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Payment is not charged now. Your record will be '
                            'marked UNPAID and settled later.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Confirm button ───────────────────────────────────
                  ElevatedButton.icon(
                    onPressed:
                        (_isConfirming || !isOnline) ? null : _confirm,
                    icon: _isConfirming
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                        _isConfirming ? 'Confirming…' : 'Confirm Boarding'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 60),
                      textStyle: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed:
                        _isConfirming ? null : () => context.pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white60, size: 16),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(color: Colors.white60, fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14),
          ),
        ),
      ],
    );
  }
}
