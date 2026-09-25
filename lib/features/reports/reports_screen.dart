import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import 'reports_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _isExporting = false;

  final Map<String, String> _reportTypes = {
    'daily-passenger': 'Daily Passenger Volume',
    'daily-revenue': 'Daily Revenue Breakdown',
    'monthly-revenue': 'Monthly Financial Revenue',
    'route-usage': 'Route Ridership & Usage',
    'boarding-location': 'Boarding Activity by Stop',
    'monthly-pass': 'Monthly Passes Issued',
    'trip': 'Comprehensive Transit Trips',
  };

  Future<void> _pickDateRange(ReportParams current) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 730)),
      lastDate: now.add(const Duration(days: 30)),
    );

    if (picked != null) {
      ref.read(reportParamsProvider.notifier).update(
        (p) => p.copyWith(
          from: Formatters.formatDate(picked.start),
          to: Formatters.formatDate(picked.end),
        ),
      );
    }
  }

  Future<void> _handleCsvExport(ReportParams params) async {
    setState(() => _isExporting = true);
    try {
      final api = ref.read(apiClientProvider);
      await ReportExporter.exportCsv(api, params);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV Report downloaded successfully'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = ref.watch(reportParamsProvider);
    final reportAsync = ref.watch(reportDataProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Controls Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Select Report
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: params.reportType,
                        decoration: const InputDecoration(labelText: 'Select Report Type'),
                        items: _reportTypes.entries.map((e) {
                          return DropdownMenuItem(value: e.key, child: Text(e.value));
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            ref.read(reportParamsProvider.notifier).update((p) => p.copyWith(reportType: v));
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Date Range
                    OutlinedButton.icon(
                      onPressed: () => _pickDateRange(params),
                      icon: const Icon(Icons.calendar_month_outlined, size: 16),
                      label: Text(
                        params.from != null && params.to != null
                            ? '${params.from} to ${params.to}'
                            : 'Last 30 Days (Default)',
                      ),
                    ),
                    const SizedBox(width: 12),

                    if (params.from != null || params.to != null)
                      TextButton(
                        onPressed: () => ref.read(reportParamsProvider.notifier).update((p) => ReportParams(reportType: p.reportType)),
                        child: const Text('Reset Range'),
                      ),

                    const Spacer(),

                    // Export Button
                    ElevatedButton.icon(
                      onPressed: _isExporting ? null : () => _handleCsvExport(params),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                      ),
                      icon: _isExporting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text('Export CSV'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Preview Table Card
            Expanded(
              child: Card(
                child: reportAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Failed to load report data: $err', style: const TextStyle(color: AppTheme.danger))),
                  data: (data) {
                    if (data.rows.isEmpty) {
                      return const Center(child: Text('No data found for this report and date range'));
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Report Header Info
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppTheme.border)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_reportTypes[data.reportType] ?? data.reportType} (Preview)',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              Text(
                                '${data.rows.length} rows recorded',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),

                        // Table
                        Expanded(
                          child: SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: data.headers.map((h) => DataColumn(label: Text(h))).toList(),
                                rows: data.rows.map((row) {
                                  return DataRow(
                                    cells: row.map((cell) {
                                      final text = cell?.toString() ?? '-';
                                      return DataCell(Text(text));
                                    }).toList(),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
