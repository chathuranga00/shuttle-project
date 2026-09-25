import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_download.dart';
import 'qr_print_provider.dart';

class QrPrintScreen extends ConsumerStatefulWidget {
  const QrPrintScreen({super.key});

  @override
  ConsumerState<QrPrintScreen> createState() => _QrPrintScreenState();
}

class _QrPrintScreenState extends ConsumerState<QrPrintScreen> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final stopsAsync = ref.watch(printableStopsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Action Header (Hidden or styled during print)
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Filter stop by name or code...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Print-ready physical stop signage',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => FileDownloadUtils.printWindow(),
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('Print Cards (Browser Print)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Grid of Printable Cards
            Expanded(
              child: stopsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading QR codes: $err', style: const TextStyle(color: AppTheme.danger))),
                data: (stops) {
                  final filtered = stops.where((s) {
                    if (_filter.isEmpty) return true;
                    return s.stopName.toLowerCase().contains(_filter) ||
                        s.stopCode.toLowerCase().contains(_filter);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text('No bus stops found to print'));
                  }

                  return SingleChildScrollView(
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 24,
                      children: filtered.map((stop) {
                        return Container(
                          width: 320,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black26, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Top Branding
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.airport_shuttle, color: Colors.white, size: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'CAMPUS SHUTTLE',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Stop Name
                              Text(
                                stop.stopName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Code Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceMuted,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Text(
                                  stop.stopCode,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                    color: AppTheme.primaryDark,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // QR Code
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: QrImageView(
                                  data: stop.signedPayload,
                                  version: QrVersions.auto,
                                  size: 200.0,
                                  errorCorrectionLevel: QrErrorCorrectLevel.Q,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Instructions
                              const Text(
                                'SCAN WITH STUDENT APP TO BOARD',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                stop.address ?? 'Official University Shuttle Transit Stop',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
