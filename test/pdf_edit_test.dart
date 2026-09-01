import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tk_office/models/pdf_edit_model.dart';

void main() {
  group('PdfEditModel Tests', () {
    test('PdfElement Serialization and Deserialization', () {
      final elem = PdfElement(
        id: 'elem_123',
        pageNumber: 1,
        type: PdfElementType.text,
        x: 45.0,
        y: 120.0,
        width: 180.0,
        height: 35.0,
        text: 'Invoice Number: 9942',
        fontSize: 18.0,
        textColor: Colors.blue,
        backgroundColor: Colors.white,
        isBold: true,
        isItalic: false,
      );

      final map = elem.toMap();
      final restored = PdfElement.fromMap(map);

      expect(restored.id, 'elem_123');
      expect(restored.type, PdfElementType.text);
      expect(restored.text, 'Invoice Number: 9942');
      expect(restored.fontSize, 18.0);
      expect(restored.isBold, true);
      expect(restored.backgroundColor, isNotNull);
    });

    test('PdfElement Whiteout Creation', () {
      final whiteout = PdfElement(
        id: 'whiteout_1',
        pageNumber: 2,
        type: PdfElementType.whiteout,
        x: 10.0,
        y: 20.0,
        width: 100.0,
        height: 50.0,
      );

      final map = whiteout.toMap();
      final restored = PdfElement.fromMap(map);

      expect(restored.type, PdfElementType.whiteout);
      expect(restored.width, 100.0);
    });
  });
}
