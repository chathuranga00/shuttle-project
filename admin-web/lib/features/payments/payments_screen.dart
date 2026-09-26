import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import 'payments_provider.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    ref.read(paymentsQueryProvider.notifier).update(
      (q) => q.copyWith(search: _searchCtrl.text.trim(), page: 0),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 1)),
    );

    if (picked != null) {
      final fromStr = Formatters.formatDate(picked.start);
      final toStr = Formatters.formatDate(picked.end);
      ref.read(paymentsQueryProvider.notifier).update(
        (q) => q.copyWith(from: fromStr, to: toStr, page: 0),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(paymentsQueryProvider);
    final paymentsAsync = ref.watch(paymentsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Bar
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Search
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search by student name, ID, or tx ID...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _onSearch();
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onSubmitted: (_) => _onSearch(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _onSearch,
                      child: const Text('Search'),
                    ),
                    const SizedBox(width: 16),

                    // Status Dropdown
                    DropdownButton<String?>(
                      value: query.status,
                      hint: const Text('All Statuses'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All Statuses')),
                        DropdownMenuItem(value: 'SUCCESS', child: Text('SUCCESS')),
                        DropdownMenuItem(value: 'PENDING', child: Text('PENDING')),
                        DropdownMenuItem(value: 'FAILED', child: Text('FAILED')),
                      ],
                      onChanged: (v) {
                        ref.read(paymentsQueryProvider.notifier).update(
                          (q) => q.copyWith(status: v, clearStatus: v == null, page: 0),
                        );
                      },
                    ),
                    const SizedBox(width: 16),

                    // Date Range Picker Button
                    OutlinedButton.icon(
                      onPressed: _pickDateRange,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        query.from != null && query.to != null
                            ? '${query.from} to ${query.to}'
                            : 'Select Date Range',
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Clear Filters
                    if (query.status != null || query.from != null || query.search.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(paymentsQueryProvider.notifier).update(
                            (q) => const PaymentsQuery(),
                          );
                        },
                        icon: const Icon(Icons.clear_all, size: 16),
                        label: const Text('Reset'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Table Card
            Expanded(
              child: Card(
                child: paymentsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppTheme.danger))),
                  data: (pageData) {
                    if (pageData.items.isEmpty) {
                      return const Center(child: Text('No payment transactions match filters'));
                    }

                    return Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: SizedBox(
                              width: double.infinity,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('TX ID')),
                                  DataColumn(label: Text('STUDENT')),
                                  DataColumn(label: Text('AMOUNT')),
                                  DataColumn(label: Text('TYPE')),
                                  DataColumn(label: Text('METHOD')),
                                  DataColumn(label: Text('DATE & TIME')),
                                  DataColumn(label: Text('STATUS')),
                                ],
                                rows: pageData.items.map((payment) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(
                                        payment.gatewayTransactionId ?? '#${payment.id}',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                      )),
                                      DataCell(Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(payment.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Text(payment.studentCode, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                        ],
                                      )),
                                      DataCell(Text(
                                        Formatters.formatCurrency(payment.amount),
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      )),
                                      DataCell(Text(payment.type)),
                                      DataCell(Text(payment.method ?? 'CARD')),
                                      DataCell(Text(Formatters.formatDateTime(payment.createdAt))),
                                      DataCell(Formatters.statusBadge(payment.status)),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),

                        // Pagination Footer
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: AppTheme.border)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Showing ${pageData.items.length} of ${pageData.totalElements} records',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              ),
                              Row(
                                children: [
                                  OutlinedButton(
                                    onPressed: pageData.currentPage > 0
                                        ? () => ref
                                            .read(paymentsQueryProvider.notifier)
                                            .update((q) => q.copyWith(page: q.page - 1))
                                        : null,
                                    child: const Text('Previous'),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Page ${pageData.currentPage + 1} of ${pageData.totalPages}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 12),
                                  OutlinedButton(
                                    onPressed: pageData.currentPage < pageData.totalPages - 1
                                        ? () => ref
                                            .read(paymentsQueryProvider.notifier)
                                            .update((q) => q.copyWith(page: q.page + 1))
                                        : null,
                                    child: const Text('Next'),
                                  ),
                                ],
                              ),
                            ],
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
