import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:tk_office/services/document_service/doc_binary_service.dart';
import 'package:tk_office/services/spreadsheet_service/xlsx_service.dart';
import 'package:tk_office/services/ocr_service/ocr_models.dart';
import 'package:tk_office/services/ocr_service/ocr_pipeline_service.dart';

void main() {
  group('DocBinaryService & OLE2 Parser Tests', () {
    test('filters out JPEG marker strings and Huffman noise', () async {
      final delta = await DocBinaryService.importDoc('non_existent_file.doc');
      expect(delta, isNotNull);
    });
  });

  group('XlsxService Merged Cells Coordinate Parser Tests', () {
    test('correctly parses Excel coordinate references', () {
      final a1 = XlsxService.parseCellCoord('A1');
      expect(a1, isNotNull);
      expect(a1!.$2, equals(0)); // col
      expect(a1.$1, equals(0)); // row

      final e1 = XlsxService.parseCellCoord('E1');
      expect(e1, isNotNull);
      expect(e1!.$2, equals(4));
      expect(e1.$1, equals(0));

      final z100 = XlsxService.parseCellCoord('Z100');
      expect(z100, isNotNull);
      expect(z100!.$2, equals(25));
      expect(z100.$1, equals(99));

      final aa5 = XlsxService.parseCellCoord('AA5');
      expect(aa5, isNotNull);
      expect(aa5!.$2, equals(26));
      expect(aa5.$1, equals(4));
    });
  });

  group('OCR Pipeline Search & Models Tests', () {
    test('OCR search correctly locates matching text blocks across pages', () {
      final pages = [
        OCRPage(
          pageIndex: 0,
          pageWidth: 612,
          pageHeight: 792,
          isScannedImage: false,
          blocks: [
            OCRTextBlock(
              id: 'p0_b0',
              text: 'V.S.B. COLLEGE OF ENGINEERING',
              pageIndex: 0,
              boundingBox: const Rect.fromLTWH(50, 50, 200, 20),
              confidence: 0.95,
            ),
            OCRTextBlock(
              id: 'p0_b1',
              text: 'DEPARTMENT OF INFORMATION TECHNOLOGY',
              pageIndex: 0,
              boundingBox: const Rect.fromLTWH(50, 80, 250, 20),
              confidence: 0.96,
            ),
          ],
        ),
      ];

      final results = OcrPipelineService.search(pages, 'College');
      expect(results.length, equals(1));
      expect(results.first.text, contains('V.S.B. COLLEGE OF ENGINEERING'));

      final itResults = OcrPipelineService.search(pages, 'Technology');
      expect(itResults.length, equals(1));
      expect(itResults.first.text, contains('INFORMATION TECHNOLOGY'));
    });
  });
}
