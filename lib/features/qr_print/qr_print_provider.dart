import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../routes_stops/routes_stops_provider.dart';

class PrintableStopQr {
  final int stopId;
  final String stopName;
  final String stopCode;
  final String signedPayload;
  final String? address;

  const PrintableStopQr({
    required this.stopId,
    required this.stopName,
    required this.stopCode,
    required this.signedPayload,
    this.address,
  });
}

final printableStopsProvider = FutureProvider.autoDispose<List<PrintableStopQr>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final stops = await ref.watch(stopsProvider.future);

  final List<PrintableStopQr> list = [];
  for (final stop in stops) {
    try {
      final res = await api.get(ApiEndpoints.stopQrPayload(stop.id));
      final data = res.data as Map<String, dynamic>;
      list.add(
        PrintableStopQr(
          stopId: stop.id,
          stopName: stop.name,
          stopCode: data['stopCode'] as String? ?? stop.qrCode,
          signedPayload: data['signedPayload'] as String? ?? stop.qrCode,
          address: stop.address,
        ),
      );
    } catch (_) {
      // Fallback to stop code
      list.add(
        PrintableStopQr(
          stopId: stop.id,
          stopName: stop.name,
          stopCode: stop.qrCode,
          signedPayload: stop.qrCode,
          address: stop.address,
        ),
      );
    }
  }

  return list;
});
