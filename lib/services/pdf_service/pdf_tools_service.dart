import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart' show Rect, Offset;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as px;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../document_service/docx_service.dart';
import '../ocr_service/ocr_service.dart';

class PdfToolsService {
  // -------------------------------------------------------------
  // 1. MERGE PDFS
  // -------------------------------------------------------------
  static Future<String> mergePdfs(List<String> inputPaths, String outputPath) async {
    if (inputPaths.isEmpty) throw Exception('No PDF files selected for merging.');

    final sf.PdfDocument outputDoc = sf.PdfDocument();

    for (final path in inputPaths) {
      final bytes = await File(path).readAsBytes();
      final sf.PdfDocument doc = sf.PdfDocument(inputBytes: bytes);
      for (int i = 0; i < doc.pages.count; i++) {
        final sf.PdfTemplate template = doc.pages[i].createTemplate();
        final sf.PdfPage newPage = outputDoc.pages.add();
        newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
      }
      doc.dispose();
    }

    final outputBytes = outputDoc.saveSync();
    outputDoc.dispose();

    final file = File(outputPath);
    await file.writeAsBytes(outputBytes);
    return outputPath;
  }

  // -------------------------------------------------------------
  // 2. SPLIT PDF
  // -------------------------------------------------------------
  static Future<List<String>> splitPdfByRanges({
    required String inputPath,
    required List<String> ranges, // e.g. ["1-3", "4-5"]
    required String outputDir,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final sf.PdfDocument srcDoc = sf.PdfDocument(inputBytes: bytes);
    final List<String> outputPaths = [];
    final baseName = p.basenameWithoutExtension(inputPath);

    int partIndex = 1;
    for (final rangeStr in ranges) {
      final pageIndices = _parseRange(rangeStr, srcDoc.pages.count);
      if (pageIndices.isEmpty) continue;

      final sf.PdfDocument partDoc = sf.PdfDocument();
      for (final idx in pageIndices) {
        final sf.PdfTemplate template = srcDoc.pages[idx].createTemplate();
        final sf.PdfPage newPage = partDoc.pages.add();
        newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
      }

      final outPath = p.join(outputDir, '${baseName}_part$partIndex.pdf');
      final partBytes = partDoc.saveSync();
      partDoc.dispose();

      await File(outPath).writeAsBytes(partBytes);
      outputPaths.add(outPath);
      partIndex++;
    }

    srcDoc.dispose();
    return outputPaths;
  }

  static List<int> _parseRange(String rangeStr, int totalPages) {
    final List<int> indices = [];
    final parts = rangeStr.split('-');
    if (parts.length == 1) {
      final pNum = int.tryParse(parts[0].trim());
      if (pNum != null && pNum >= 1 && pNum <= totalPages) {
        indices.add(pNum - 1);
      }
    } else if (parts.length == 2) {
      final start = int.tryParse(parts[0].trim()) ?? 1;
      final end = int.tryParse(parts[1].trim()) ?? totalPages;
      final clampedStart = start.clamp(1, totalPages);
      final clampedEnd = end.clamp(clampedStart, totalPages);
      for (int i = clampedStart; i <= clampedEnd; i++) {
        indices.add(i - 1);
      }
    }
    return indices;
  }

  // -------------------------------------------------------------
  // 3. DELETE / REORDER / ROTATE / EXTRACT / DUPLICATE PAGES
  // -------------------------------------------------------------
  static Future<String> deletePages({
    required String inputPath,
    required List<int> pagesToDelete1Indexed,
    required String outputPath,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final sf.PdfDocument srcDoc = sf.PdfDocument(inputBytes: bytes);
    final sf.PdfDocument outDoc = sf.PdfDocument();

    for (int i = 0; i < srcDoc.pages.count; i++) {
      final pageNum = i + 1;
      if (!pagesToDelete1Indexed.contains(pageNum)) {
        final sf.PdfTemplate template = srcDoc.pages[i].createTemplate();
        final sf.PdfPage newPage = outDoc.pages.add();
        newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
      }
    }

    final outBytes = outDoc.saveSync();
    outDoc.dispose();
    srcDoc.dispose();

    await File(outputPath).writeAsBytes(outBytes);
    return outputPath;
  }

  static Future<String> reorderPages({
    required String inputPath,
    required List<int> newOrder1Indexed, // e.g. [3, 1, 2]
    required String outputPath,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final sf.PdfDocument srcDoc = sf.PdfDocument(inputBytes: bytes);
    final sf.PdfDocument outDoc = sf.PdfDocument();

    for (final pageNum in newOrder1Indexed) {
      if (pageNum >= 1 && pageNum <= srcDoc.pages.count) {
        final sf.PdfTemplate template = srcDoc.pages[pageNum - 1].createTemplate();
        final sf.PdfPage newPage = outDoc.pages.add();
        newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
      }
    }

    final outBytes = outDoc.saveSync();
    outDoc.dispose();
    srcDoc.dispose();

    await File(outputPath).writeAsBytes(outBytes);
    return outputPath;
  }

  static Future<String> rotatePages({
    required String inputPath,
    required List<int> pagesToRotate1Indexed,
    required int rotationAngle, // 90, 180, 270
    required String outputPath,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final sf.PdfDocument doc = sf.PdfDocument(inputBytes: bytes);

    for (final pageNum in pagesToRotate1Indexed) {
      if (pageNum >= 1 && pageNum <= doc.pages.count) {
        final page = doc.pages[pageNum - 1];
        if (rotationAngle == 90) {
          page.rotation = sf.PdfPageRotateAngle.rotateAngle90;
        } else if (rotationAngle == 180) {
          page.rotation = sf.PdfPageRotateAngle.rotateAngle180;
        } else if (rotationAngle == 270) {
          page.rotation = sf.PdfPageRotateAngle.rotateAngle270;
        }
      }
    }

    final outBytes = doc.saveSync();
    doc.dispose();

    await File(outputPath).writeAsBytes(outBytes);
    return outputPath;
  }

  static Future<String> duplicatePage({
    required String inputPath,
    required int pageToDuplicate1Indexed,
    required String outputPath,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final sf.PdfDocument srcDoc = sf.PdfDocument(inputBytes: bytes);
    final sf.PdfDocument outDoc = sf.PdfDocument();

    for (int i = 0; i < srcDoc.pages.count; i++) {
      final pageNum = i + 1;
      final template = srcDoc.pages[i].createTemplate();
      final newPage = outDoc.pages.add();
      newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));

      if (pageNum == pageToDuplicate1Indexed) {
        // Insert duplicate immediately after
        final dupPage = outDoc.pages.add();
        dupPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
      }
    }

    final outBytes = outDoc.saveSync();
    outDoc.dispose();
    srcDoc.dispose();

    await File(outputPath).writeAsBytes(outBytes);
    return outputPath;
  }

  static Future<String> extractPages({
    required String inputPath,
    required List<int> pagesToExtract1Indexed,
    required String outputPath,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final sf.PdfDocument srcDoc = sf.PdfDocument(inputBytes: bytes);
    final sf.PdfDocument outDoc = sf.PdfDocument();

    for (final pageNum in pagesToExtract1Indexed) {
      if (pageNum >= 1 && pageNum <= srcDoc.pages.count) {
        final sf.PdfTemplate template = srcDoc.pages[pageNum - 1].createTemplate();
        final sf.PdfPage newPage = outDoc.pages.add();
        newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
      }
    }

    final outBytes = outDoc.saveSync();
    outDoc.dispose();
    srcDoc.dispose();

    await File(outputPath).writeAsBytes(outBytes);
    return outputPath;
  }

  // -------------------------------------------------------------
  // 4. PDF COMPRESSION
  // -------------------------------------------------------------
  static Future<String> compressPdf({
    required String inputPath,
    required String outputPath,
    int imageQuality = 60, // 0-100
  }) async {
    final px.PdfDocument pdfDoc = await px.PdfDocument.openFile(inputPath);
    final pw.Document compressedDoc = pw.Document();

    for (int i = 1; i <= pdfDoc.pagesCount; i++) {
      final page = await pdfDoc.getPage(i);
      final pageImage = await page.render(
        width: page.width * 1.5,
        height: page.height * 1.5,
        format: px.PdfPageImageFormat.jpeg,
      );
      await page.close();

      if (pageImage != null) {
        // Re-compress via image package
        final decoded = img.decodeImage(pageImage.bytes);
        if (decoded != null) {
          final recompressedBytes = Uint8List.fromList(
            img.encodeJpg(decoded, quality: imageQuality),
          );
          final pwImage = pw.MemoryImage(recompressedBytes);

          compressedDoc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(page.width.toDouble(), page.height.toDouble()),
              margin: pw.EdgeInsets.zero,
              build: (pw.Context context) {
                return pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Image(pwImage, fit: pw.BoxFit.fill),
                );
              },
            ),
          );
        }
      }
    }

    await pdfDoc.close();
    final savedBytes = await compressedDoc.save();
    await File(outputPath).writeAsBytes(savedBytes);
    return outputPath;
  }

  // -------------------------------------------------------------
  // 5. WATERMARKS (TEXT & IMAGE)
  // -------------------------------------------------------------
  static Future<String> addWatermarkText({
    required String inputPath,
    required String outputPath,
    required String watermarkText,
    double opacity = 0.3,
    double fontSize = 48,
    double angle = -45,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final sf.PdfDocument doc = sf.PdfDocument(inputBytes: bytes);

    final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, fontSize, style: sf.PdfFontStyle.bold);
    final brush = sf.PdfSolidBrush(sf.PdfColor(150, 150, 150, (opacity * 255).toInt()));

    for (int i = 0; i < doc.pages.count; i++) {
      final page = doc.pages[i];
      final graphics = page.graphics;
      final size = font.measureString(watermarkText);

      graphics.save();
      graphics.translateTransform(page.size.width / 2, page.size.height / 2);
      graphics.rotateTransform(angle);
      graphics.drawString(
        watermarkText,
        font,
        brush: brush,
        bounds: Rect.fromLTWH(-size.width / 2, -size.height / 2, size.width, size.height),
      );
      graphics.restore();
    }

    final outBytes = doc.saveSync();
    doc.dispose();

    await File(outputPath).writeAsBytes(outBytes);
    return outputPath;
  }

  static Future<String> addWatermarkImage({
    required String inputPath,
    required String outputPath,
    required String imagePath,
    double opacity = 0.3,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final sf.PdfDocument doc = sf.PdfDocument(inputBytes: bytes);

    final imageBytes = await File(imagePath).readAsBytes();
    final sf.PdfBitmap bitmap = sf.PdfBitmap(imageBytes);

    for (int i = 0; i < doc.pages.count; i++) {
      final page = doc.pages[i];
      final graphics = page.graphics;
      final w = page.size.width * 0.6;
      final h = (bitmap.height / bitmap.width) * w;
      final x = (page.size.width - w) / 2;
      final y = (page.size.height - h) / 2;

      graphics.save();
      graphics.setTransparency(opacity);
      graphics.drawImage(bitmap, Rect.fromLTWH(x, y, w, h));
      graphics.restore();
    }

    final outBytes = doc.saveSync();
    doc.dispose();

    await File(outputPath).writeAsBytes(outBytes);
    return outputPath;
  }

  // -------------------------------------------------------------
  // 6. ELECTRONIC SIGNATURE
  // -------------------------------------------------------------
  static Future<String> stampSignature({
    required String inputPath,
    required String outputPath,
    required String signatureImagePath,
    required int pageNumber1Indexed,
    required double x,
    required double y,
    required double width,
    required double height,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final sf.PdfDocument doc = sf.PdfDocument(inputBytes: bytes);

    if (pageNumber1Indexed >= 1 && pageNumber1Indexed <= doc.pages.count) {
      final page = doc.pages[pageNumber1Indexed - 1];
      final sigBytes = await File(signatureImagePath).readAsBytes();
      final sf.PdfBitmap bitmap = sf.PdfBitmap(sigBytes);
      page.graphics.drawImage(bitmap, Rect.fromLTWH(x, y, width, height));
    }

    final outBytes = doc.saveSync();
    doc.dispose();

    await File(outputPath).writeAsBytes(outBytes);
    return outputPath;
  }

  // -------------------------------------------------------------
  // 7. PASSWORD PROTECTION & UNLOCK
  // -------------------------------------------------------------
  static Future<String> protectPdf({
    required String inputPath,
    required String outputPath,
    required String userPassword,
    String? ownerPassword,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final sf.PdfDocument doc = sf.PdfDocument(inputBytes: bytes);

    final security = doc.security;
    security.userPassword = userPassword;
    if (ownerPassword != null && ownerPassword.isNotEmpty) {
      security.ownerPassword = ownerPassword;
    }
    security.algorithm = sf.PdfEncryptionAlgorithm.aesx256BitRevision6;

    final outBytes = doc.saveSync();
    doc.dispose();

    await File(outputPath).writeAsBytes(outBytes);
    return outputPath;
  }

  static Future<String> unlockPdf({
    required String inputPath,
    required String outputPath,
    required String password,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final sf.PdfDocument doc = sf.PdfDocument(inputBytes: bytes, password: password);
    final sf.PdfDocument unencrypted = sf.PdfDocument();

    for (int i = 0; i < doc.pages.count; i++) {
      final template = doc.pages[i].createTemplate();
      final newPage = unencrypted.pages.add();
      newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
    }

    final cleanBytes = unencrypted.saveSync();
    unencrypted.dispose();
    doc.dispose();

    await File(outputPath).writeAsBytes(cleanBytes);
    return outputPath;
  }

  // -------------------------------------------------------------
  // 8. PDF TO IMAGES
  // -------------------------------------------------------------
  static Future<List<String>> convertPdfToImages({
    required String inputPath,
    required String outputDir,
    String format = 'png', // 'png' or 'jpg'
    int dpi = 150,
  }) async {
    final pdfDoc = await px.PdfDocument.openFile(inputPath);
    final baseName = p.basenameWithoutExtension(inputPath);
    final List<String> imagePaths = [];

    for (int i = 1; i <= pdfDoc.pagesCount; i++) {
      final page = await pdfDoc.getPage(i);
      final scale = (dpi / 72.0).clamp(1.0, 4.0);
      final pageImage = await page.render(
        width: page.width * scale,
        height: page.height * scale,
        format: format == 'jpg' ? px.PdfPageImageFormat.jpeg : px.PdfPageImageFormat.png,
      );
      await page.close();

      if (pageImage != null) {
        final outPath = p.join(outputDir, '${baseName}_page_${i.toString().padLeft(3, '0')}.$format');
        await File(outPath).writeAsBytes(pageImage.bytes);
        imagePaths.add(outPath);
      }
    }

    await pdfDoc.close();
    return imagePaths;
  }

  // -------------------------------------------------------------
  // 9. IMAGES TO PDF
  // -------------------------------------------------------------
  static Future<String> convertImagesToPdf({
    required List<String> imagePaths,
    required String outputPath,
    String pageSize = 'A4',
    String orientation = 'portrait',
    double margin = 10,
  }) async {
    final pdf = pw.Document();

    PdfPageFormat format = PdfPageFormat.a4;
    if (pageSize.toUpperCase() == 'A3') format = PdfPageFormat.a3;
    if (pageSize.toUpperCase() == 'LETTER') format = PdfPageFormat.letter;
    if (pageSize.toUpperCase() == 'LEGAL') format = PdfPageFormat.legal;

    if (orientation.toLowerCase() == 'landscape') {
      format = format.landscape;
    }

    for (final imgPath in imagePaths) {
      if (File(imgPath).existsSync()) {
        final bytes = await File(imgPath).readAsBytes();
        final image = pw.MemoryImage(bytes);

        pdf.addPage(
          pw.Page(
            pageFormat: format,
            margin: pw.EdgeInsets.all(margin),
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(image, fit: pw.BoxFit.contain),
              );
            },
          ),
        );
      }
    }

    final savedBytes = await pdf.save();
    await File(outputPath).writeAsBytes(savedBytes);
    return outputPath;
  }

  // -------------------------------------------------------------
  // 10. PDF TO TEXT (VECTOR + OCR FALLBACK)
  // -------------------------------------------------------------
  static Future<String> extractTextFromPdf(String inputPath) async {
    try {
      final bytes = await File(inputPath).readAsBytes();
      final sf.PdfDocument doc = sf.PdfDocument(inputBytes: bytes);
      final extractor = sf.PdfTextExtractor(doc);
      final text = extractor.extractText();
      doc.dispose();

      if (text.trim().isNotEmpty) {
        return text;
      }
    } catch (_) {}

    // Fallback to offline on-device OCR
    return await OcrService.recognizeTextFromPdf(pdfPath: inputPath);
  }

  // -------------------------------------------------------------
  // 11. PDF TO DOCX
  // -------------------------------------------------------------
  static Future<String> convertPdfToDocx(String inputPath, String outputPath) async {
    final text = await extractTextFromPdf(inputPath);

    final delta = Delta();
    final lines = text.split('\n');
    for (final line in lines) {
      delta.insert('$line\n');
    }

    final docxBytes = DocxService.exportToDocx(delta);
    await File(outputPath).writeAsBytes(docxBytes);
    return outputPath;
  }

  // -------------------------------------------------------------
  // 12. PDF TO XLSX / CSV (TABLE DETECTION)
  // -------------------------------------------------------------
  static Future<String> convertPdfToXlsx(String inputPath, String outputPath) async {
    final text = await extractTextFromPdf(inputPath);
    final excel = xl.Excel.createExcel();
    final sheet = excel['Sheet1'];

    final lines = text.split('\n');
    int rowIdx = 0;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Detect delimiters: tabs, multiple spaces, commas
      final cells = trimmed.contains('\t')
          ? trimmed.split('\t')
          : trimmed.contains(',')
              ? trimmed.split(',')
              : trimmed.split(RegExp(r'\s{2,}'));

      for (int colIdx = 0; colIdx < cells.length; colIdx++) {
        final cellValue = cells[colIdx].trim();
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: rowIdx)).value =
            xl.TextCellValue(cellValue);
      }
      rowIdx++;
    }

    final bytes = excel.encode()!;
    await File(outputPath).writeAsBytes(bytes);
    return outputPath;
  }

  static Future<String> convertPdfToCsv(String inputPath, String outputPath) async {
    final text = await extractTextFromPdf(inputPath);
    final List<List<dynamic>> rows = [];

    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final cells = trimmed.contains('\t')
          ? trimmed.split('\t')
          : trimmed.contains(',')
              ? trimmed.split(',')
              : trimmed.split(RegExp(r'\s{2,}'));
      rows.add(cells.map((c) => c.trim()).toList());
    }

    final csvContent = const ListToCsvConverter().convert(rows);
    await File(outputPath).writeAsString(csvContent);
    return outputPath;
  }
}
