import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

Future<void> downloadPdf(Uint8List pdfBytes, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(pdfBytes);
  // You can add additional logic to open the file or show a success message.
}
