import 'dart:io';
import '../../pdf_service/pdf_tools_service.dart';

class PdfToXlsxConverter {
  static Future<File> convert({
    required String inputPdfPath,
    required String outputXlsxPath,
    Function(String stage)? onProgress,
  }) async {
    onProgress?.call('Detecting tables & building Excel spreadsheet...');
    await PdfToolsService.convertPdfToXlsx(inputPdfPath, outputXlsxPath);
    final outputFile = File(outputXlsxPath);
    if (!outputFile.existsSync() || outputFile.lengthSync() == 0) {
      throw Exception('PDF to XLSX conversion failed: output file is empty.');
    }
    return outputFile;
  }
}
