import 'dart:io';
import 'package:flutter/material.dart' show Color;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as px;
import '../../models/pdf_edit_model.dart';

class PdfBakerService {
  /// Renders the original PDF with all edited elements (Text, Images, Whiteouts)
  /// and saves the output to [outputPath].
  static Future<String> bakeAndSavePdf({
    required String originalPdfPath,
    required List<PdfElement> elements,
    required String outputPath,
  }) async {
    final originalDoc = await px.PdfDocument.openFile(originalPdfPath);
    final pageCount = originalDoc.pagesCount;
    final pdfDoc = pw.Document();

    for (int pageNum = 1; pageNum <= pageCount; pageNum++) {
      final page = await originalDoc.getPage(pageNum);
      // Render page image at crisp 2x resolution
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: px.PdfPageImageFormat.png,
      );
      await page.close();

      if (pageImage == null) continue;

      final bgImage = pw.MemoryImage(pageImage.bytes);
      final pageWidth = page.width.toDouble();
      final pageHeight = page.height.toDouble();

      final pageElements = elements.where((e) => e.pageNumber == pageNum).toList();

      pdfDoc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(pageWidth, pageHeight),
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Stack(
              fit: pw.StackFit.expand,
              children: [
                // 1. Original Page Background
                pw.Image(bgImage, fit: pw.BoxFit.fill),

                // 2. Overlaid Edits
                ...pageElements.map((elem) {
                  return pw.Positioned(
                    left: elem.x,
                    top: elem.y,
                    child: pw.SizedBox(
                      width: elem.width,
                      height: elem.height,
                      child: _buildPdfElementWidget(elem),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      );
    }

    await originalDoc.close();

    final bytes = await pdfDoc.save();
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(bytes);
    return outputPath;
  }

  static pw.Widget _buildPdfElementWidget(PdfElement elem) {
    switch (elem.type) {
      case PdfElementType.whiteout:
        return pw.Container(
          color: _toPdfColor(elem.whiteoutColor),
        );

      case PdfElementType.image:
        if (elem.imageBytes != null) {
          final image = pw.MemoryImage(elem.imageBytes!);
          return pw.Image(image, fit: pw.BoxFit.contain);
        } else if (elem.imagePath != null && File(elem.imagePath!).existsSync()) {
          final bytes = File(elem.imagePath!).readAsBytesSync();
          final image = pw.MemoryImage(bytes);
          return pw.Image(image, fit: pw.BoxFit.contain);
        }
        return pw.Container();

      case PdfElementType.text:
        return pw.Container(
          color: elem.backgroundColor != null ? _toPdfColor(elem.backgroundColor!) : null,
          alignment: _toPwAlignment(elem.textAlign),
          child: pw.Text(
            elem.text,
            style: pw.TextStyle(
              fontSize: elem.fontSize,
              color: _toPdfColor(elem.textColor),
              fontWeight: elem.isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontStyle: elem.isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
            ),
          ),
        );
    }
  }

  static PdfColor _toPdfColor(Color c) {
    return PdfColor(
      c.r,
      c.g,
      c.b,
      c.a,
    );
  }

  static pw.Alignment _toPwAlignment(dynamic align) {
    switch (align.toString()) {
      case 'TextAlign.center':
        return pw.Alignment.center;
      case 'TextAlign.right':
        return pw.Alignment.centerRight;
      default:
        return pw.Alignment.centerLeft;
    }
  }
}
