import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

class OcrResult {
  final String text;
  final bool isSuccess;
  final String? errorMessage;

  OcrResult({
    required this.text,
    this.isSuccess = true,
    this.errorMessage,
  });
}

class OcrService {
  /// Extracts text from PDF using pure offline Dart engine
  static Future<String> recognizeTextFromPdf({
    required String pdfPath,
    Function(int current, int total)? onProgress,
  }) async {
    try {
      final bytes = await File(pdfPath).readAsBytes();
      final sf.PdfDocument doc = sf.PdfDocument(inputBytes: bytes);
      final extractor = sf.PdfTextExtractor(doc);
      final totalPages = doc.pages.count;
      final StringBuffer fullText = StringBuffer();

      for (int i = 0; i < totalPages; i++) {
        onProgress?.call(i + 1, totalPages);
        final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
        fullText.writeln('--- Page ${i + 1} ---');
        fullText.writeln(pageText);
        fullText.writeln();
      }

      doc.dispose();
      return fullText.toString();
    } catch (e) {
      return 'Text extraction error: \$e';
    }
  }
}
