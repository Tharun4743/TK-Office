import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tk_office/services/document_service/docx_service.dart';

void main() {
  group('DocxService Unit Tests', () {
    test('Export Delta to DOCX bytes and re-import', () {
      final delta = Delta()
        ..insert('Hello TK Office!\n', {'bold': true})
        ..insert('This is a test paragraph with italic styling.\n', {'italic': true})
        ..insert('End of document.\n');

      final bytes = DocxService.exportToDocx(delta);
      expect(bytes.isNotEmpty, true);

      final importedDelta = DocxService.importDocxBytes(bytes);
      expect(importedDelta.isNotEmpty, true);
      
      final text = importedDelta.toList().map((op) => op.data).join('');
      expect(text.contains('Hello TK Office!'), true);
      expect(text.contains('italic styling'), true);
    });
  });
}
