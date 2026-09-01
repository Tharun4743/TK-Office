import 'dart:io';
import '../../pdf_service/pdf_tools_service.dart';

class PdfToDocxConverter {
  static Future<File> convert({
    required String inputPdfPath,
    required String outputDocxPath,
    Function(String stage)? onProgress,
  }) async {
    onProgress?.call('Extracting text & formatting OpenXML...');
    await PdfToolsService.convertPdfToDocx(inputPdfPath, outputDocxPath);
    final outputFile = File(outputDocxPath);
    if (!outputFile.existsSync() || outputFile.lengthSync() == 0) {
      throw Exception('PDF to DOCX conversion failed: output file is empty.');
    }
    return outputFile;
  }
}
