import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/driver_providers.dart';

/// Screen allowing driver to file immediate emergency reports.
/// Calls POST /api/driver/emergency-report (type, description, optional location).
/// Spec Section 18: Large touch targets, high contrast, fast submission.
class EmergencyReportScreen extends ConsumerStatefulWidget {
  const EmergencyReportScreen({super.key});

  @override
  ConsumerState<EmergencyReportScreen> createState() =>
      _EmergencyReportScreenState();
}

class _EmergencyReportScreenState extends ConsumerState<EmergencyReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedType = 'BREAKDOWN';
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _emergencyTypes = [
    {
      'type': 'ACCIDENT',
      'label': 'Accident / Collision',
      'icon': Icons.car_crash_rounded,
      'color': Colors.red.shade700,
    },
    {
      'type': 'BREAKDOWN',
      'label': 'Mechanical Breakdown',
      'icon': Icons.build_circle_rounded,
      'color': Colors.orange.shade800,
    },
    {
      'type': 'MEDICAL',
      'label': 'Medical Emergency',
      'icon': Icons.medical_services_rounded,
      'color': Colors.pink.shade700,
    },
    {
      'type': 'DELAY',
      'label': 'Major Route Delay',
      'icon': Icons.hourglass_top_rounded,
      'color': Colors.amber.shade800,
    },
    {
      'type': 'SECURITY',
      'label': 'Safety / Security',
      'icon': Icons.security_rounded,
      'color': Colors.purple.shade700,
    },
    {
      'type': 'OTHER',
      'label': 'Other Incident',
      'icon': Icons.warning_rounded,
      'color': Colors.blueGrey.shade700,
    },
  ];

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final currentTrip = ref.read(currentTripProvider).valueOrNull;

    final report =
        await ref.read(driverActionControllerProvider.notifier).reportEmergency(
              type: _selectedType,
              description: _descriptionController.text.trim(),
              location: _locationController.text.trim().isNotEmpty
                  ? _locationController.text.trim()
                  : null,
              tripId: currentTrip?.id,
            );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (report != null) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            report.status == 'QUEUED_OFFLINE'
                ? Icons.cloud_queue_rounded
                : Icons.check_circle_rounded,
            color: report.status == 'QUEUED_OFFLINE'
                ? Colors.amber.shade800
                : Colors.green.shade700,
            size: 56,
          ),
          title: Text(report.status == 'QUEUED_OFFLINE'
              ? 'Incident Queued Offline'
              : 'Incident Reported'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.status == 'QUEUED_OFFLINE'
                    ? 'Your emergency report has been saved securely offline.'
                    : 'Your emergency report (#${report.id}) has been recorded.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                report.status == 'QUEUED_OFFLINE'
                    ? 'It will be automatically synced with Campus Dispatch as soon as your device reconnects to the network.'
                    : 'Campus Dispatch and Shuttle Admins have been notified immediately.\n\n'
                        'Please stay with the vehicle and follow university transit safety procedures.',
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                Navigator.pop(ctx);
                context.pop();
              },
              child: const Text('Return to Portal'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Failed to submit emergency report. Please check your connection or call dispatch.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTrip = ref.watch(currentTripProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Report'),
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Urgent Notice ─────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.red.shade800, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Filing this report sends an immediate high-priority alert to Campus Transit Dispatch.',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Active Trip Link ──────────────────────────────
              if (currentTrip != null && currentTrip.isActive)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded,
                          size: 18, color: Colors.blueGrey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Attaching to Active Trip: ${currentTrip.routeName} (Bus ${currentTrip.busNumber})',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Incident Type Selector ────────────────────────
              const Text(
                '1. Select Incident Type',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.1,
                children: _emergencyTypes.map((item) {
                  final isSelected = _selectedType == item['type'];
                  final Color color = item['color'] as Color;

                  return InkWell(
                    onTap: () =>
                        setState(() => _selectedType = item['type'] as String),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.12)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? color : Colors.grey.shade300,
                          width: isSelected ? 2.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(item['icon'] as IconData,
                              color: isSelected ? color : Colors.grey.shade700,
                              size: 26),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item['label'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: isSelected ? color : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // ── Location ──────────────────────────────────────
              const Text(
                '2. Current Location (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  hintText: 'e.g. Near Science Quad, Stop 3, Main Highway',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Description ───────────────────────────────────
              const Text(
                '3. Describe Situation',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please provide a brief description of the incident';
                  }
                  if (val.trim().length < 5) {
                    return 'Description must be at least 5 characters';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText:
                      'Provide brief details: nature of issue, student safety status, assistance required...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Submit Button ─────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 60, // Large button per spec section 18
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade800,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submitReport,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.emergency_share_rounded, size: 28),
                  label: Text(
                    _isSubmitting
                        ? 'TRANSMITTING REPORT...'
                        : 'SUBMIT EMERGENCY REPORT',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
