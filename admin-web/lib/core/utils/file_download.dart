import 'dart:convert';
import 'package:universal_html/html.dart' as html;

class FileDownloadUtils {
  static void downloadCsv(String csvContent, String filename) {
    final bytes = utf8.encode(csvContent);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  static void printWindow() {
    html.window.print();
  }
}
