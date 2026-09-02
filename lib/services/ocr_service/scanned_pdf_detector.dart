import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'ocr_models.dart';

/// Analyzes PDF documents and individual pages to detect whether they contain
/// native selectable text or scanned raster images.
class ScannedPdfDetector {
  /// Analyzes all pages of a PDF and returns the classification for each page
  static Future<List<PdfPageType>> detectPageTypes(String pdfPath) async {
    final List<PdfPageType> pageTypes = [];
    try {
      final file = File(pdfPath);
      if (!await file.exists()) return pageTypes;

      final bytes = await file.readAsBytes();
      final sf.PdfDocument doc = sf.PdfDocument(inputBytes: bytes);
      final extractor = sf.PdfTextExtractor(doc);

      for (int i = 0; i < doc.pages.count; i++) {
        final text = extractor.extractText(startPageIndex: i, endPageIndex: i).trim();
        if (text.length > 50) {
          pageTypes.add(PdfPageType.nativeText);
        } else if (text.isEmpty) {
          pageTypes.add(PdfPageType.scannedImage);
        } else {
          pageTypes.add(PdfPageType.mixed);
        }
      }

      doc.dispose();
    } catch (_) {
      // Default to nativeText on error to avoid breaking standard viewing
    }
    return pageTypes;
  }

  /// Checks if a PDF is predominantly a scanned document
  static Future<bool> isScannedDocument(String pdfPath) async {
    final types = await detectPageTypes(pdfPath);
    if (types.isEmpty) return false;
    final scannedCount = types.where((t) => t == PdfPageType.scannedImage).length;
    return (scannedCount / types.length) >= 0.5;
  }
}
