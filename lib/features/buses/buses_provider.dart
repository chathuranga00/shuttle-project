import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

class BusItem {
  final int id;
  final String busNumber;
  final String plateNumber;
  final int capacity;
  final String? model;
  final String status;

  const BusItem({
    required this.id,
    required this.busNumber,
    required this.plateNumber,
    required this.capacity,
    this.model,
    required this.status,
  });

  factory BusItem.fromJson(Map<String, dynamic> json) {
    return BusItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      busNumber: json['busNumber'] as String? ?? '',
      plateNumber: json['plateNumber'] as String? ?? '',
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      model: json['model'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
    );
  }

  bool get isActive => status.toUpperCase() == 'ACTIVE';
}

final busesProvider = FutureProvider.autoDispose<List<BusItem>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get(ApiEndpoints.buses);
  final list = response.data as List? ?? [];
  return list.map((item) => BusItem.fromJson(item as Map<String, dynamic>)).toList();
});
