import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tk_office/services/conversion_service/conversion_registry.dart';
import 'package:tk_office/services/conversion_service/converters/docx_to_pdf_converter.dart';
import 'package:tk_office/services/conversion_service/converters/pdf_to_docx_converter.dart';
import 'package:tk_office/services/conversion_service/converters/pdf_to_xlsx_converter.dart';
import 'package:tk_office/services/conversion_service/converters/pptx_to_pdf_converter.dart';
import 'package:tk_office/services/conversion_service/converters/xlsx_to_pdf_converter.dart';
import 'package:tk_office/shared/widgets/save_file_dialog.dart';

class FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async {
    return Directory.systemTemp.path;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = FakePathProviderPlatform();

  group('Conversion Engine & Universal Save-As Tests', () {
    test('SaveFileDialog sanitizeFileName prevents duplicate extensions and strips invalid chars', () {
      expect(SaveFileDialog.sanitizeFileName('assignment', '.pdf'), 'assignment.pdf');
      expect(SaveFileDialog.sanitizeFileName('assignment.pdf', '.pdf'), 'assignment.pdf');
      expect(SaveFileDialog.sanitizeFileName('report.PDF', '.pdf'), 'report.PDF');
      expect(SaveFileDialog.sanitizeFileName('my/invalid:doc?name', '.docx'), 'my_invalid_doc_name.docx');
      expect(SaveFileDialog.sanitizeFileName('sheet.xlsx', '.xlsx'), 'sheet.xlsx');
    });

    test('ConversionRegistry contains all 12 offline converters and flags them as supported', () {
      expect(ConversionRegistry.allOptions.length, 12);
      for (final opt in ConversionRegistry.allOptions) {
        expect(opt.isSupported, isTrue);
        expect(opt.targetExtension.startsWith('.'), isTrue);
      }
    });

    test('DocxToPdfConverter converts real DOCX OpenXML to valid vector PDF', () async {
      final tempDir = Directory.systemTemp.createTempSync('docx_test');
      final docxPath = '${tempDir.path}/sample.docx';
      final pdfPath = '${tempDir.path}/output.pdf';

      // Create a real minimal DOCX zip
      final archive = Archive();
      const docXml = '''<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:r><w:t>Hello TK Office DOCX to PDF Conversion</w:t></w:r>
    </w:p>
  </w:body>
</w:document>''';
      archive.addFile(ArchiveFile('word/document.xml', docXml.length, utf8.encode(docXml)));
      final docxBytes = ZipEncoder().encode(archive)!;
      await File(docxPath).writeAsBytes(docxBytes);

      final resultFile = await DocxToPdfConverter.convert(
        inputDocxPath: docxPath,
        outputPdfPath: pdfPath,
      );

      expect(await resultFile.exists(), isTrue);
      expect(resultFile.lengthSync(), greaterThan(0));
      final header = String.fromCharCodes((await resultFile.readAsBytes()).take(4));
      expect(header, '%PDF');

      tempDir.deleteSync(recursive: true);
    });

    test('XlsxToPdfConverter converts real XLSX spreadsheet to valid vector PDF table', () async {
      final tempDir = Directory.systemTemp.createTempSync('xlsx_test');
      final xlsxPath = '${tempDir.path}/sample.xlsx';
      final pdfPath = '${tempDir.path}/output.pdf';

      // Create a real minimal XLSX
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];
      sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Product');
      sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Price');
      sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue('App');
      sheet.cell(CellIndex.indexByString('B2')).value = DoubleCellValue(99.0);
      await File(xlsxPath).writeAsBytes(excel.encode()!);

      final resultFile = await XlsxToPdfConverter.convert(
        inputXlsxPath: xlsxPath,
        outputPdfPath: pdfPath,
      );

      expect(await resultFile.exists(), isTrue);
      expect(resultFile.lengthSync(), greaterThan(0));
      final header = String.fromCharCodes((await resultFile.readAsBytes()).take(4));
      expect(header, '%PDF');

      tempDir.deleteSync(recursive: true);
    });

    test('PptxToPdfConverter converts real PPTX presentation to valid 16:9 PDF deck', () async {
      final tempDir = Directory.systemTemp.createTempSync('pptx_test');
      final pptxPath = '${tempDir.path}/sample.pptx';
      final pdfPath = '${tempDir.path}/output.pdf';

      // Create a real minimal PPTX zip
      final archive = Archive();
      const slideXml = '''<?xml version="1.0" encoding="UTF-8"?>
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:sp>
        <p:txBody>
          <a:p><a:r><a:t>TK Office Slide Title</a:t></a:r></a:p>
          <a:p><a:r><a:t>Key Presentation Point</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';
      archive.addFile(ArchiveFile('ppt/slides/slide1.xml', slideXml.length, utf8.encode(slideXml)));
      final pptxBytes = ZipEncoder().encode(archive)!;
      await File(pptxPath).writeAsBytes(pptxBytes);

      final resultFile = await PptxToPdfConverter.convert(
        inputPptxPath: pptxPath,
        outputPdfPath: pdfPath,
      );

      expect(await resultFile.exists(), isTrue);
      expect(resultFile.lengthSync(), greaterThan(0));
      final header = String.fromCharCodes((await resultFile.readAsBytes()).take(4));
      expect(header, '%PDF');

      tempDir.deleteSync(recursive: true);
    });

    test('PdfToDocxConverter converts PDF into real OpenXML DOCX document', () async {
      final tempDir = Directory.systemTemp.createTempSync('pdf_to_docx_test');
      final pdfPath = '${tempDir.path}/input.pdf';
      final docxPath = '${tempDir.path}/output.docx';

      // Generate a valid text PDF
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Center(
            child: pw.Text('Sample Text for Word Extraction'),
          ),
        ),
      );
      await File(pdfPath).writeAsBytes(await pdf.save());

      final resultFile = await PdfToDocxConverter.convert(
        inputPdfPath: pdfPath,
        outputDocxPath: docxPath,
      );

      expect(await resultFile.exists(), isTrue);
      expect(resultFile.lengthSync(), greaterThan(0));

      // Verify DOCX ZIP contains word/document.xml
      final zip = ZipDecoder().decodeBytes(await resultFile.readAsBytes());
      expect(zip.files.any((f) => f.name == 'word/document.xml'), isTrue);

      tempDir.deleteSync(recursive: true);
    });

    test('PdfToXlsxConverter extracts tabular data from PDF into real XLSX workbook', () async {
      final tempDir = Directory.systemTemp.createTempSync('pdf_to_xlsx_test');
      final pdfPath = '${tempDir.path}/input.pdf';
      final xlsxPath = '${tempDir.path}/output.xlsx';

      // Generate a PDF with tab-delimited text
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Column(
            children: [
              pw.Text('Item\tQty\tPrice'),
              pw.Text('Laptop\t2\t1500'),
            ],
          ),
        ),
      );
      await File(pdfPath).writeAsBytes(await pdf.save());

      final resultFile = await PdfToXlsxConverter.convert(
        inputPdfPath: pdfPath,
        outputXlsxPath: xlsxPath,
      );

      expect(await resultFile.exists(), isTrue);
      expect(resultFile.lengthSync(), greaterThan(0));

      tempDir.deleteSync(recursive: true);
    });
  });
}
