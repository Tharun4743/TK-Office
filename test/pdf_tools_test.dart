import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tk_office/services/pdf_service/pdf_tools_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfToolsService Tests', () {
    late Directory tempDir;
    late String samplePdf1;
    late String samplePdf2;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('tk_pdf_test_');

      // Create Sample PDF 1 (2 pages)
      final doc1 = pw.Document();
      doc1.addPage(pw.Page(build: (ctx) => pw.Center(child: pw.Text('Document 1 Page 1'))));
      doc1.addPage(pw.Page(build: (ctx) => pw.Center(child: pw.Text('Document 1 Page 2'))));
      samplePdf1 = '${tempDir.path}/doc1.pdf';
      await File(samplePdf1).writeAsBytes(await doc1.save());

      // Create Sample PDF 2 (1 page)
      final doc2 = pw.Document();
      doc2.addPage(pw.Page(build: (ctx) => pw.Center(child: pw.Text('Document 2 Page 1'))));
      samplePdf2 = '${tempDir.path}/doc2.pdf';
      await File(samplePdf2).writeAsBytes(await doc2.save());
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('Merge Multiple PDFs', () async {
      final mergedPath = '${tempDir.path}/merged.pdf';
      await PdfToolsService.mergePdfs([samplePdf1, samplePdf2], mergedPath);

      expect(File(mergedPath).existsSync(), isTrue);
      expect(File(mergedPath).lengthSync(), greaterThan(500));
    });

    test('Split PDF by Page Ranges', () async {
      final splitFiles = await PdfToolsService.splitPdfByRanges(
        inputPath: samplePdf1,
        ranges: ['1', '2'],
        outputDir: tempDir.path,
      );

      expect(splitFiles.length, 2);
      expect(File(splitFiles[0]).existsSync(), isTrue);
      expect(File(splitFiles[1]).existsSync(), isTrue);
    });

    test('Delete Pages from PDF', () async {
      final deletedPath = '${tempDir.path}/deleted.pdf';
      await PdfToolsService.deletePages(
        inputPath: samplePdf1,
        pagesToDelete1Indexed: [2],
        outputPath: deletedPath,
      );

      expect(File(deletedPath).existsSync(), isTrue);
      expect(File(deletedPath).lengthSync(), greaterThan(200));
    });

    test('Rotate Pages in PDF', () async {
      final rotatedPath = '${tempDir.path}/rotated.pdf';
      await PdfToolsService.rotatePages(
        inputPath: samplePdf1,
        pagesToRotate1Indexed: [1],
        rotationAngle: 90,
        outputPath: rotatedPath,
      );

      expect(File(rotatedPath).existsSync(), isTrue);
    });

    test('Watermark Text on PDF', () async {
      final wmPath = '${tempDir.path}/watermarked.pdf';
      await PdfToolsService.addWatermarkText(
        inputPath: samplePdf1,
        outputPath: wmPath,
        watermarkText: 'CONFIDENTIAL',
        opacity: 0.25,
      );

      expect(File(wmPath).existsSync(), isTrue);
    });

    test('Password Protect and Unlock PDF', () async {
      final protectedPath = '${tempDir.path}/protected.pdf';
      final unlockedPath = '${tempDir.path}/unlocked.pdf';

      await PdfToolsService.protectPdf(
        inputPath: samplePdf1,
        outputPath: protectedPath,
        userPassword: 'secretPassword123',
      );

      expect(File(protectedPath).existsSync(), isTrue);

      await PdfToolsService.unlockPdf(
        inputPath: protectedPath,
        outputPath: unlockedPath,
        password: 'secretPassword123',
      );

      expect(File(unlockedPath).existsSync(), isTrue);
    });
  });
}
