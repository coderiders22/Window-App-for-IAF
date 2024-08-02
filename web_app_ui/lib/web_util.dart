// lib/web_util.dart
import 'dart:html';
import 'dart:typed_data';

void downloadPdf(Uint8List pdfBytes, String fileName) {
  final blob = Blob([pdfBytes]);
  final url = Url.createObjectUrlFromBlob(blob);
  AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  Url.revokeObjectUrl(url);
}
