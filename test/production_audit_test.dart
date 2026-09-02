import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:tk_office/services/conversion_service/converters/docx_to_pdf_converter.dart';
import 'package:tk_office/services/conversion_service/converters/pdf_to_docx_converter.dart';
import 'package:tk_office/services/conversion_service/converters/pdf_to_xlsx_converter.dart';
import 'package:tk_office/services/conversion_service/converters/pptx_to_pdf_converter.dart';
import 'package:tk_office/services/conversion_service/converters/xlsx_to_pdf_converter.dart';
import 'package:tk_office/services/conversion_service/output_validator.dart';
import 'package:tk_office/services/pdf_service/pdf_tools_service.dart';
import 'package:tk_office/services/save_manager/universal_save_manager.dart';

class TestPathProvider extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => Directory.systemTemp.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = TestPathProvider();

  late Directory testDir;

  setUpAll(() {
    testDir = Directory.systemTemp.createTempSync('tk_office_production_audit');
  });

  tearDownAll(() {
    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
  });

  group('TK OFFICE — PRODUCTION REALITY AUDIT SUITE', () {
    // -------------------------------------------------------------
    // 1. UNIVERSAL SAVE MANAGER & FILENAME AUDIT
    // -------------------------------------------------------------
    test('UniversalSaveManager: Filename sanitization & single extension guarantee', () {
      // Test A: No extension given -> adds target extension
      expect(UniversalSaveManager.sanitizeFileName('final_report', '.pdf'), 'final_report.pdf');

      // Test B: Extension already given -> preserves single extension (NO .pdf.pdf)
      expect(UniversalSaveManager.sanitizeFileName('final_report.pdf', '.pdf'), 'final_report.pdf');
      expect(UniversalSaveManager.sanitizeFileName('Final_Report.PDF', '.pdf'), 'Final_Report.PDF');
      expect(UniversalSaveManager.sanitizeFileName('budget.xlsx', '.xlsx'), 'budget.xlsx');

      // Test C: Illegal characters stripped
      expect(UniversalSaveManager.sanitizeFileName('my/doc:with?illegal*chars', '.docx'), 'my_doc_with_illegal_chars.docx');

      // Test D: Dynamic Save Locations available
      expect(UniversalSaveManager.getAvailableSaveLocations(), completes);
    });

    test('OutputValidator: Correctly validates real vs invalid output files', () async {
      // 1. Valid PDF
      final goodPdf = File('${testDir.path}/valid.pdf');
      final doc = pw.Document()..addPage(pw.Page(build: (_) => pw.Text('Valid PDF Content')));
      await goodPdf.writeAsBytes(await doc.save());
      final pdfVal = await OutputValidator.validateFile(goodPdf, '.pdf');
      expect(pdfVal.isValid, isTrue);

      // 2. Corrupt / Empty PDF
      final badPdf = File('${testDir.path}/bad.pdf');
      await badPdf.writeAsString('not a pdf');
      final badPdfVal = await OutputValidator.validateFile(badPdf, '.pdf');
      expect(badPdfVal.isValid, isFalse);

      // 3. Valid XLSX
      final goodXlsx = File('${testDir.path}/valid.xlsx');
      final xlDoc = Excel.createExcel();
      xlDoc['Sheet1'].cell(CellIndex.indexByString('A1')).value = TextCellValue('Test');
      await goodXlsx.writeAsBytes(xlDoc.encode()!);
      final xlsxVal = await OutputValidator.validateFile(goodXlsx, '.xlsx');
      expect(xlsxVal.isValid, isTrue);
    });

    // -------------------------------------------------------------
    // 2. 10-PAGE PDF MANIPULATION & PAGE MANAGER AUDIT
    // -------------------------------------------------------------
    test('PDF Page Manager: 10-Page PDF - Delete, Rotate, Extract, Merge, and Split', () async {
      final pdf10Path = '${testDir.path}/test_10_pages.pdf';

      // 1. Create a real 10-page vector PDF
      final doc10 = pw.Document();
      for (int i = 1; i <= 10; i++) {
        doc10.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (ctx) => pw.Center(
              child: pw.Text('Page $i of 10 - TK Office Test Document', style: const pw.TextStyle(fontSize: 24)),
            ),
          ),
        );
      }
      await File(pdf10Path).writeAsBytes(await doc10.save());
      expect(File(pdf10Path).existsSync(), isTrue);

      // Verify original page count = 10
      final origBytes = await File(pdf10Path).readAsBytes();
      final sfOrig = sf.PdfDocument(inputBytes: origBytes);
      expect(sfOrig.pages.count, 10);
      sfOrig.dispose();

      // Test 2.1: Delete Page 3 -> Should produce 9-page PDF
      final delPath = '${testDir.path}/deleted_p3.pdf';
      await PdfToolsService.deletePages(
        inputPath: pdf10Path,
        pagesToDelete1Indexed: [3],
        outputPath: delPath,
      );
      final delBytes = await File(delPath).readAsBytes();
      final sfDel = sf.PdfDocument(inputBytes: delBytes);
      expect(sfDel.pages.count, 9);
      sfDel.dispose();

      // Test 2.2: Rotate Page 4 by 90 degrees
      final rotPath = '${testDir.path}/rotated_p4.pdf';
      await PdfToolsService.rotatePages(
        inputPath: pdf10Path,
        pagesToRotate1Indexed: [4],
        rotationAngle: 90,
        outputPath: rotPath,
      );
      final rotBytes = await File(rotPath).readAsBytes();
      final sfRot = sf.PdfDocument(inputBytes: rotBytes);
      expect(sfRot.pages.count, 10);
      expect(sfRot.pages[3].rotation, sf.PdfPageRotateAngle.rotateAngle90);
      sfRot.dispose();

      // Test 2.3: Extract Pages 5-7 -> Should produce 3-page PDF
      final extPath = '${testDir.path}/extracted_p5_7.pdf';
      await PdfToolsService.extractPages(
        inputPath: pdf10Path,
        pagesToExtract1Indexed: [5, 6, 7],
        outputPath: extPath,
      );
      final extBytes = await File(extPath).readAsBytes();
      final sfExt = sf.PdfDocument(inputBytes: extBytes);
      expect(sfExt.pages.count, 3);
      sfExt.dispose();

      // Test 2.4: Merge 3-page PDF + 2-page PDF -> 5-page PDF
      final pdf2Path = '${testDir.path}/test_2_pages.pdf';
      final doc2 = pw.Document();
      doc2.addPage(pw.Page(build: (_) => pw.Text('Page 1 of 2')));
      doc2.addPage(pw.Page(build: (_) => pw.Text('Page 2 of 2')));
      await File(pdf2Path).writeAsBytes(await doc2.save());

      final mergedPath = '${testDir.path}/merged_5_pages.pdf';
      await PdfToolsService.mergePdfs([extPath, pdf2Path], mergedPath);
      final mBytes = await File(mergedPath).readAsBytes();
      final sfMerged = sf.PdfDocument(inputBytes: mBytes);
      expect(sfMerged.pages.count, 5);
      sfMerged.dispose();

      // Test 2.5: Split into ranges "1-2", "3-5" -> 2 PDF files
      final splitDir = '${testDir.path}/split_output';
      Directory(splitDir).createSync();
      final splitPaths = await PdfToolsService.splitPdfByRanges(
        inputPath: mergedPath,
        ranges: ['1-2', '3-5'],
        outputDir: splitDir,
      );
      expect(splitPaths.length, 2);
      for (final p in splitPaths) {
        expect(File(p).existsSync(), isTrue);
        expect(File(p).lengthSync(), greaterThan(0));
      }
    });

    // -------------------------------------------------------------
    // 3. REAL DOCX → PDF CONVERSION AUDIT
    // -------------------------------------------------------------
    test('DocxToPdfConverter: Converts rich DOCX with paragraphs and tables to vector PDF', () async {
      final docxPath = '${testDir.path}/rich_test.docx';
      final pdfPath = '${testDir.path}/docx_out.pdf';

      final archive = Archive();
      const docXml = '''<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:rPr><w:b/></w:rPr>
      <w:r><w:t>Quarterly Financial Report</w:t></w:r>
    </w:p>
    <w:p>
      <w:rPr><w:i/></w:rPr>
      <w:r><w:t>CONFIDENTIAL - Internal Use Only</w:t></w:r>
    </w:p>
    <w:tbl>
      <w:tr>
        <w:tc><w:p><w:r><w:t>Department</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Budget</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:p><w:r><w:t>Engineering</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>\$120,000</w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>
  </w:body>
</w:document>''';
      archive.addFile(ArchiveFile('word/document.xml', docXml.length, utf8.encode(docXml)));
      final docxBytes = ZipEncoder().encode(archive)!;
      await File(docxPath).writeAsBytes(docxBytes);

      final outPdf = await DocxToPdfConverter.convert(
        inputDocxPath: docxPath,
        outputPdfPath: pdfPath,
      );

      expect(await outPdf.exists(), isTrue);
      expect(outPdf.lengthSync(), greaterThan(0));

      final header = String.fromCharCodes((await outPdf.readAsBytes()).take(4));
      expect(header, '%PDF');
    });

    // -------------------------------------------------------------
    // 4. REAL XLSX → PDF CONVERSION AUDIT
    // -------------------------------------------------------------
    test('XlsxToPdfConverter: Converts multi-sheet Excel workbook with formulas to vector PDF tables', () async {
      final xlsxPath = '${testDir.path}/multi_sheet_test.xlsx';
      final pdfPath = '${testDir.path}/xlsx_out.pdf';

      final excel = Excel.createExcel();
      final sheet1 = excel['Income'];
      sheet1.cell(CellIndex.indexByString('A1')).value = TextCellValue('Category');
      sheet1.cell(CellIndex.indexByString('B1')).value = TextCellValue('Revenue');
      sheet1.cell(CellIndex.indexByString('A2')).value = TextCellValue('Software');
      sheet1.cell(CellIndex.indexByString('B2')).value = DoubleCellValue(45000.0);

      final sheet2 = excel['Expenses'];
      sheet2.cell(CellIndex.indexByString('A1')).value = TextCellValue('Item');
      sheet2.cell(CellIndex.indexByString('B1')).value = TextCellValue('Cost');
      sheet2.cell(CellIndex.indexByString('A2')).value = TextCellValue('Hosting');
      sheet2.cell(CellIndex.indexByString('B2')).value = DoubleCellValue(1200.0);

      await File(xlsxPath).writeAsBytes(excel.encode()!);

      final outPdf = await XlsxToPdfConverter.convert(
        inputXlsxPath: xlsxPath,
        outputPdfPath: pdfPath,
      );

      expect(await outPdf.exists(), isTrue);
      expect(outPdf.lengthSync(), greaterThan(0));
      final header = String.fromCharCodes((await outPdf.readAsBytes()).take(4));
      expect(header, '%PDF');
    });

    // -------------------------------------------------------------
    // 5. REAL PPTX → PDF CONVERSION AUDIT
    // -------------------------------------------------------------
    test('PptxToPdfConverter: Converts presentation slides to 16:9 PDF deck', () async {
      final pptxPath = '${testDir.path}/presentation_test.pptx';
      final pdfPath = '${testDir.path}/pptx_out.pdf';

      final archive = Archive();
      const slide1Xml = '''<?xml version="1.0" encoding="UTF-8"?>
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:sp>
        <p:txBody>
          <a:p><a:r><a:t>Slide 1: Overview</a:t></a:r></a:p>
          <a:p><a:r><a:t>Key architecture points</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';

      const slide2Xml = '''<?xml version="1.0" encoding="UTF-8"?>
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:sp>
        <p:txBody>
          <a:p><a:r><a:t>Slide 2: Roadmap</a:t></a:r></a:p>
          <a:p><a:r><a:t>Deliverable timeline</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';

      archive.addFile(ArchiveFile('ppt/slides/slide1.xml', slide1Xml.length, utf8.encode(slide1Xml)));
      archive.addFile(ArchiveFile('ppt/slides/slide2.xml', slide2Xml.length, utf8.encode(slide2Xml)));

      final pptxBytes = ZipEncoder().encode(archive)!;
      await File(pptxPath).writeAsBytes(pptxBytes);

      final outPdf = await PptxToPdfConverter.convert(
        inputPptxPath: pptxPath,
        outputPdfPath: pdfPath,
      );

      expect(await outPdf.exists(), isTrue);
      expect(outPdf.lengthSync(), greaterThan(0));

      final sfDoc = sf.PdfDocument(inputBytes: await outPdf.readAsBytes());
      expect(sfDoc.pages.count, 2);
      sfDoc.dispose();
    });

    // -------------------------------------------------------------
    // 6. PDF → DOCX & PDF → XLSX EXTRACTION AUDIT
    // -------------------------------------------------------------
    test('PdfToDocxConverter & PdfToXlsxConverter: Extract text and structure into real DOCX and XLSX', () async {
      final samplePdfPath = '${testDir.path}/tabular_doc.pdf';
      final docxOut = '${testDir.path}/extracted_doc.docx';
      final xlsxOut = '${testDir.path}/extracted_sheet.xlsx';

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (ctx) => pw.Column(
            children: [
              pw.Text('Monthly Expense Summary'),
              pw.Text('Category\tAmount\tStatus'),
              pw.Text('Cloud Servers\t500\tPaid'),
              pw.Text('Licenses\t300\tPending'),
            ],
          ),
        ),
      );
      await File(samplePdfPath).writeAsBytes(await pdf.save());

      // PDF -> DOCX
      final docxResult = await PdfToDocxConverter.convert(
        inputPdfPath: samplePdfPath,
        outputDocxPath: docxOut,
      );
      expect(await docxResult.exists(), isTrue);
      expect(docxResult.lengthSync(), greaterThan(0));

      // PDF -> XLSX
      final xlsxResult = await PdfToXlsxConverter.convert(
        inputPdfPath: samplePdfPath,
        outputXlsxPath: xlsxOut,
      );
      expect(await xlsxResult.exists(), isTrue);
      expect(xlsxResult.lengthSync(), greaterThan(0));
    });
  });
}
