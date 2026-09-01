import 'dart:io';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class XlsxToPdfConverter {
  static Future<File> convert({
    required String inputXlsxPath,
    required String outputPdfPath,
    Function(String stage)? onProgress,
  }) async {
    onProgress?.call('Reading Excel workbook...');
    final bytes = await File(inputXlsxPath).readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    final pdf = pw.Document();

    onProgress?.call('Converting spreadsheet sheets to PDF...');
    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null || sheet.maxRows == 0) continue;

      final List<List<String>> tableData = [];
      for (final row in sheet.rows) {
        final rowList = row.map((cell) => _cleanText(cell?.value?.toString() ?? '')).toList();
        // Skip completely empty rows
        if (rowList.any((val) => val.trim().isNotEmpty)) {
          tableData.add(rowList);
        }
      }

      if (tableData.isEmpty) continue;

      // Determine max columns
      int maxCols = 0;
      for (final r in tableData) {
        if (r.length > maxCols) maxCols = r.length;
      }

      // Normalize row lengths
      for (final r in tableData) {
        while (r.length < maxCols) {
          r.add('');
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: maxCols > 6 ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          header: (context) => pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Text(
              'Sheet: $table',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
            ),
          ),
          build: (context) => [
            pw.TableHelper.fromTextArray(
              data: tableData,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
          ],
        ),
      );
    }

    onProgress?.call('Finalizing PDF export...');
    final outputFile = File(outputPdfPath);
    await outputFile.writeAsBytes(await pdf.save());
    return outputFile;
  }

  static String _cleanText(String input) {
    return input
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('…', '...')
        .replaceAll('•', '*')
        .replaceAll('\u2022', '*')
        .replaceAll('\u00A0', ' ');
  }
}
