import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

class PaymentItem {
  final int id;
  final int studentId;
  final String studentName;
  final String studentCode;
  final double amount;
  final String status;
  final String type;
  final String? method;
  final String? providerReference;
  final String? gatewayTransactionId;
  final String createdAt;

  const PaymentItem({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    required this.amount,
    required this.status,
    required this.type,
    this.method,
    this.providerReference,
    this.gatewayTransactionId,
    required this.createdAt,
  });

  factory PaymentItem.fromJson(Map<String, dynamic> json) {
    return PaymentItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      studentId: (json['studentId'] as num?)?.toInt() ?? 0,
      studentName: json['studentName'] as String? ?? 'Student',
      studentCode: json['studentCode'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'SUCCESS',
      type: json['type'] as String? ?? 'WALLET_TOPUP',
      method: json['method'] as String?,
      providerReference: json['providerReference'] as String?,
      gatewayTransactionId: json['gatewayTransactionId'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class PaymentsQuery {
  final int page;
  final int size;
  final String? status;
  final String? from;
  final String? to;
  final String search;

  const PaymentsQuery({
    this.page = 0,
    this.size = 10,
    this.status,
    this.from,
    this.to,
    this.search = '',
  });

  PaymentsQuery copyWith({
    int? page,
    int? size,
    String? status,
    bool clearStatus = false,
    String? from,
    String? to,
    bool clearDates = false,
    String? search,
  }) {
    return PaymentsQuery(
      page: page ?? this.page,
      size: size ?? this.size,
      status: clearStatus ? null : (status ?? this.status),
      from: clearDates ? null : (from ?? this.from),
      to: clearDates ? null : (to ?? this.to),
      search: search ?? this.search,
    );
  }
}

class PaymentsPageData {
  final List<PaymentItem> items;
  final int totalElements;
  final int totalPages;
  final int currentPage;

  const PaymentsPageData({
    required this.items,
    required this.totalElements,
    required this.totalPages,
    required this.currentPage,
  });
}

final paymentsQueryProvider = StateProvider<PaymentsQuery>((ref) {
  return const PaymentsQuery();
});

final paymentsProvider = FutureProvider.autoDispose<PaymentsPageData>((ref) async {
  final api = ref.watch(apiClientProvider);
  final query = ref.watch(paymentsQueryProvider);

  final response = await api.get(
    ApiEndpoints.payments,
    queryParameters: {
      'page': query.page,
      'size': query.size,
      if (query.status != null && query.status!.isNotEmpty) 'status': query.status,
      if (query.from != null && query.from!.isNotEmpty) 'from': query.from,
      if (query.to != null && query.to!.isNotEmpty) 'to': query.to,
      if (query.search.isNotEmpty) 'search': query.search,
    },
  );

  final data = response.data as Map<String, dynamic>;
  final content = (data['content'] as List? ?? [])
      .map((item) => PaymentItem.fromJson(item as Map<String, dynamic>))
      .toList();

  return PaymentsPageData(
    items: content,
    totalElements: (data['totalElements'] as num?)?.toInt() ?? 0,
    totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
    currentPage: (data['number'] as num?)?.toInt() ?? 0,
  );
});
