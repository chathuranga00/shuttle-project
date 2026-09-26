import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

class StudentItem {
  final int id;
  final int userId;
  final String studentId;
  final String fullName;
  final String email;
  final String faculty;
  final String department;
  final int? enrollmentYear;
  final String status;

  const StudentItem({
    required this.id,
    required this.userId,
    required this.studentId,
    required this.fullName,
    required this.email,
    required this.faculty,
    required this.department,
    this.enrollmentYear,
    required this.status,
  });

  factory StudentItem.fromJson(Map<String, dynamic> json) {
    return StudentItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      studentId: json['studentId'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      faculty: json['faculty'] as String? ?? '',
      department: json['department'] as String? ?? '',
      enrollmentYear: (json['enrollmentYear'] as num?)?.toInt(),
      status: json['status'] as String? ?? 'ACTIVE',
    );
  }

  bool get isActive => status.toUpperCase() == 'ACTIVE';
}

class StudentsQuery {
  final int page;
  final int size;
  final String search;

  const StudentsQuery({this.page = 0, this.size = 10, this.search = ''});

  StudentsQuery copyWith({int? page, int? size, String? search}) {
    return StudentsQuery(
      page: page ?? this.page,
      size: size ?? this.size,
      search: search ?? this.search,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentsQuery &&
          runtimeType == other.runtimeType &&
          page == other.page &&
          size == other.size &&
          search == other.search;

  @override
  int get hashCode => page.hashCode ^ size.hashCode ^ search.hashCode;
}

class StudentsPageData {
  final List<StudentItem> items;
  final int totalElements;
  final int totalPages;
  final int currentPage;

  const StudentsPageData({
    required this.items,
    required this.totalElements,
    required this.totalPages,
    required this.currentPage,
  });
}

final studentsQueryProvider = StateProvider<StudentsQuery>((ref) {
  return const StudentsQuery();
});

final studentsProvider = FutureProvider.autoDispose<StudentsPageData>((ref) async {
  final api = ref.watch(apiClientProvider);
  final query = ref.watch(studentsQueryProvider);

  final response = await api.get(
    ApiEndpoints.students,
    queryParameters: {
      'page': query.page,
      'size': query.size,
      if (query.search.isNotEmpty) 'search': query.search,
    },
  );

  final data = response.data as Map<String, dynamic>;
  final content = (data['content'] as List? ?? [])
      .map((item) => StudentItem.fromJson(item as Map<String, dynamic>))
      .toList();

  return StudentsPageData(
    items: content,
    totalElements: (data['totalElements'] as num?)?.toInt() ?? 0,
    totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
    currentPage: (data['number'] as num?)?.toInt() ?? 0,
  );
});
