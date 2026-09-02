import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/spreadsheet_model.dart';
import '../../utils/file_utils.dart';
import '../storage_service/local_storage_service.dart';
import 'csv_service.dart';
import 'formula_engine.dart';
import 'xlsx_service.dart';

class SpreadsheetService {
  Future<WorkbookModel> createNewWorkbook({String title = 'Untitled Spreadsheet'}) async {
    final path = await LocalStorageService.instance.generateUniqueFilePath(
      baseName: title,
      extension: '.xlsx',
      category: DocumentCategory.spreadsheet,
    );

    final wb = WorkbookModel(
      filePath: path,
      title: title,
      sheets: [SheetModel(name: 'Sheet1')],
      lastModified: DateTime.now(),
    );

    await saveWorkbook(wb);
    return wb;
  }

  Future<WorkbookModel> loadWorkbook(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }

    final ext = p.extension(filePath).toLowerCase();
    WorkbookModel wb;

    if (ext == '.csv') {
      wb = await CsvService.importCsv(filePath);
    } else {
      wb = await XlsxService.importXlsx(filePath);
    }

    return wb;
  }

  Future<void> saveWorkbook(WorkbookModel workbook) async {
    workbook.filePath ??= await LocalStorageService.instance.generateUniqueFilePath(
      baseName: workbook.title,
      extension: '.xlsx',
      category: DocumentCategory.spreadsheet,
    );

    final file = File(workbook.filePath!);
    final ext = p.extension(workbook.filePath!).toLowerCase();

    // Recalculate all sheets
    for (final sheet in workbook.sheets) {
      FormulaEngine.recalculateSheet(sheet);
    }

    if (ext == '.csv') {
      final csv = CsvService.exportToCsv(workbook.activeSheet);
      await file.writeAsString(csv);
    } else {
      final bytes = XlsxService.exportToXlsx(workbook);
      await file.writeAsBytes(bytes);
    }

    workbook.isDirty = false;
    workbook.lastModified = DateTime.now();
  }

  Future<String> exportToPdf(WorkbookModel workbook) async {
    final pdfDoc = pw.Document();

    for (final sheet in workbook.sheets) {
      FormulaEngine.recalculateSheet(sheet);

      // Find bounds
      var maxR = 0;
      var maxC = 0;
      for (final key in sheet.cells.keys) {
        final colLetter = key.replaceAll(RegExp(r'[0-9]'), '');
        final rowNum = int.parse(key.replaceAll(RegExp(r'[A-Za-z]'), ''));
        final c = colLetter.codeUnitAt(0) - 65;
        final r = rowNum - 1;
        if (r > maxR) maxR = r;
        if (c > maxC) maxC = c;
      }
      if (maxR > 30) maxR = 30; // Limit rows per PDF page
      if (maxC > 10) maxC = 10;

      final List<List<String>> tableData = [];
      // Header row
      final List<String> header = ['#'];
      for (var c = 0; c <= maxC; c++) {
        header.add(String.fromCharCode(65 + c));
      }
      tableData.add(header);

      for (var r = 0; r <= maxR; r++) {
        final List<String> row = ['${r + 1}'];
        for (var c = 0; c <= maxC; c++) {
          final cell = sheet.getCell(r, c);
          row.add(cell.calculatedValue.isNotEmpty ? cell.calculatedValue : cell.value);
        }
        tableData.add(row);
      }

      pdfDoc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${workbook.title} - ${sheet.name}',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                data: tableData,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(4),
              ),
            ],
          ),
        ),
      );
    }

    final pdfBytes = await pdfDoc.save();
    final pdfPath = await LocalStorageService.instance.generateUniqueFilePath(
      baseName: workbook.title,
      extension: '.pdf',
      category: DocumentCategory.pdf,
    );

    final pdfFile = File(pdfPath);
    await pdfFile.writeAsBytes(pdfBytes);
    return pdfPath;
  }

  Future<void> printWorkbook(WorkbookModel workbook) async {
    final pdfPath = await exportToPdf(workbook);
    final file = File(pdfPath);
    final bytes = await file.readAsBytes();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: workbook.title,
    );
  }
}
