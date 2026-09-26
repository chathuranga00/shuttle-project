import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils/file_download.dart';

class ReportData {
  final String reportType;
  final String from;
  final String to;
  final List<String> headers;
  final List<List<dynamic>> rows;
  final Map<String, dynamic>? summary;

  const ReportData({
    required this.reportType,
    required this.from,
    required this.to,
    required this.headers,
    required this.rows,
    this.summary,
  });

  factory ReportData.fromJson(Map<String, dynamic> json) {
    return ReportData(
      reportType: json['reportType'] as String? ?? '',
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
      headers: (json['headers'] as List? ?? []).map((e) => e.toString()).toList(),
      rows: (json['rows'] as List? ?? []).map((row) => (row as List? ?? []).toList()).toList(),
      summary: json['summary'] as Map<String, dynamic>?,
    );
  }
}

class ReportParams {
  final String reportType;
  final String? from;
  final String? to;

  const ReportParams({
    this.reportType = 'daily-passenger',
    this.from,
    this.to,
  });

  ReportParams copyWith({String? reportType, String? from, String? to}) {
    return ReportParams(
      reportType: reportType ?? this.reportType,
      from: from ?? this.from,
      to: to ?? this.to,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportParams &&
          runtimeType == other.runtimeType &&
          reportType == other.reportType &&
          from == other.from &&
          to == other.to;

  @override
  int get hashCode => reportType.hashCode ^ from.hashCode ^ to.hashCode;
}

final reportParamsProvider = StateProvider<ReportParams>((ref) {
  return const ReportParams();
});

final reportDataProvider = FutureProvider.autoDispose<ReportData>((ref) async {
  final api = ref.watch(apiClientProvider);
  final params = ref.watch(reportParamsProvider);

  final response = await api.get(
    ApiEndpoints.report(params.reportType),
    queryParameters: {
      'format': 'json',
      if (params.from != null) 'from': params.from,
      if (params.to != null) 'to': params.to,
    },
  );

  return ReportData.fromJson(response.data as Map<String, dynamic>);
});

class ReportExporter {
  static Future<void> exportCsv(ApiClient api, ReportParams params) async {
    final response = await api.get(
      ApiEndpoints.report(params.reportType),
      queryParameters: {
        'format': 'csv',
        if (params.from != null) 'from': params.from,
        if (params.to != null) 'to': params.to,
      },
      options: Options(responseType: ResponseType.plain),
    );

    final csvString = response.data.toString();
    final filename = '${params.reportType}_report_${DateTime.now().millisecondsSinceEpoch}.csv';
    FileDownloadUtils.downloadCsv(csvString, filename);
  }
}
