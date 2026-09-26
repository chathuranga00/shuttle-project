import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

class SystemSettingsData {
  final int gpsRadiusMetres;
  final bool gpsVerificationEnabled;
  final double monthlyPassPrice;

  const SystemSettingsData({
    required this.gpsRadiusMetres,
    required this.gpsVerificationEnabled,
    required this.monthlyPassPrice,
  });

  factory SystemSettingsData.fromJson(Map<String, dynamic> json) {
    return SystemSettingsData(
      gpsRadiusMetres: (json['gpsRadiusMetres'] as num?)?.toInt() ?? 100,
      gpsVerificationEnabled: json['gpsVerificationEnabled'] as bool? ?? true,
      monthlyPassPrice: (json['monthlyPassPrice'] as num?)?.toDouble() ?? 5000.0,
    );
  }
}

final systemSettingsProvider = FutureProvider.autoDispose<SystemSettingsData>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get(ApiEndpoints.settingsConfig);
  return SystemSettingsData.fromJson(response.data as Map<String, dynamic>);
});
