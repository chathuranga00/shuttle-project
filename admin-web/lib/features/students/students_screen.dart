import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import 'students_provider.dart';

class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final text = _searchController.text.trim();
    ref.read(studentsQueryProvider.notifier).update((q) => q.copyWith(search: text, page: 0));
  }

  Future<void> _toggleStatus(StudentItem student) async {
    final api = ref.read(apiClientProvider);
    try {
      final endpoint = student.isActive
          ? ApiEndpoints.suspendStudent(student.id)
          : ApiEndpoints.activateStudent(student.id);
      await api.post(endpoint);
      ref.invalidate(studentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              student.isActive
                  ? 'Student ${student.fullName} has been suspended'
                  : 'Student ${student.fullName} has been activated',
            ),
            backgroundColor: student.isActive ? AppTheme.warning : AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _deleteStudent(StudentItem student) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text('Are you sure you want to deactivate/delete ${student.fullName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.delete(ApiEndpoints.studentById(student.id));
      ref.invalidate(studentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student deleted'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete student: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _openEditDialog(StudentItem student) async {
    final nameCtrl = TextEditingController(text: student.fullName);
    final facultyCtrl = TextEditingController(text: student.faculty);
    final deptCtrl = TextEditingController(text: student.department);
    final yearCtrl = TextEditingController(text: student.enrollmentYear?.toString() ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Student: ${student.studentId}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: facultyCtrl,
                decoration: const InputDecoration(labelText: 'Faculty'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: deptCtrl,
                decoration: const InputDecoration(labelText: 'Department'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yearCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Enrollment Year'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final api = ref.read(apiClientProvider);
        await api.put(
          ApiEndpoints.studentById(student.id),
          data: {
            'fullName': nameCtrl.text.trim(),
            'faculty': facultyCtrl.text.trim(),
            'department': deptCtrl.text.trim(),
            'enrollmentYear': int.tryParse(yearCtrl.text.trim()),
          },
        );
        ref.invalidate(studentsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Student updated successfully'), backgroundColor: AppTheme.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update student: $e'), backgroundColor: AppTheme.danger),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Action Bar
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name, student ID, or faculty...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearch();
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onSubmitted: (_) => _onSearch(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _onSearch,
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Table Card
            Expanded(
              child: Card(
                child: studentsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppTheme.danger))),
                  data: (pageData) {
                    if (pageData.items.isEmpty) {
                      return const Center(
                        child: Text(
                          'No students found',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: SizedBox(
                              width: double.infinity,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('STUDENT ID')),
                                  DataColumn(label: Text('FULL NAME')),
                                  DataColumn(label: Text('EMAIL')),
                                  DataColumn(label: Text('FACULTY')),
                                  DataColumn(label: Text('YEAR')),
                                  DataColumn(label: Text('STATUS')),
                                  DataColumn(label: Text('ACTIONS')),
                                ],
                                rows: pageData.items.map((student) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(
                                        student.studentId,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      )),
                                      DataCell(Text(student.fullName)),
                                      DataCell(Text(student.email)),
                                      DataCell(Text('${student.faculty} (${student.department})')),
                                      DataCell(Text(student.enrollmentYear?.toString() ?? '-')),
                                      DataCell(Formatters.statusBadge(student.status)),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Suspend / Activate
                                            IconButton(
                                              tooltip: student.isActive ? 'Suspend Student' : 'Activate Student',
                                              icon: Icon(
                                                student.isActive ? Icons.block : Icons.check_circle_outline,
                                                size: 18,
                                                color: student.isActive ? AppTheme.warning : AppTheme.success,
                                              ),
                                              onPressed: () => _toggleStatus(student),
                                            ),
                                            // Edit
                                            IconButton(
                                              tooltip: 'Edit Student',
                                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                                              onPressed: () => _openEditDialog(student),
                                            ),
                                            // Delete
                                            IconButton(
                                              tooltip: 'Delete Student',
                                              icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                                              onPressed: () => _deleteStudent(student),
                                            ),
                                          ],
                                        ),
                                      ),
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
                                'Showing ${pageData.items.length} of ${pageData.totalElements} students',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              ),
                              Row(
                                children: [
                                  OutlinedButton(
                                    onPressed: pageData.currentPage > 0
                                        ? () => ref
                                            .read(studentsQueryProvider.notifier)
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
                                            .read(studentsQueryProvider.notifier)
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
