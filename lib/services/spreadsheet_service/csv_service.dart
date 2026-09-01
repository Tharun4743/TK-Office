import 'dart:io';
import 'package:csv/csv.dart';
import '../../models/spreadsheet_model.dart';
import 'formula_engine.dart';

class CsvService {
  static Future<WorkbookModel> importCsv(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return WorkbookModel.empty();
    }

    final content = await file.readAsString();
    final rows = const CsvToListConverter().convert(content);

    final sheet = SheetModel(
      name: 'Sheet1',
      rowCount: rows.length > 20 ? rows.length + 10 : 50,
      columnCount: 26,
    );

    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      for (var c = 0; c < row.length; c++) {
        final val = row[c].toString();
        if (val.isNotEmpty) {
          final isFormula = val.startsWith('=');
          sheet.setCell(
            r,
            c,
            CellModel(
              value: val,
              formula: isFormula ? val : null,
              calculatedValue: val,
            ),
          );
        }
      }
    }

    FormulaEngine.recalculateSheet(sheet);

    return WorkbookModel(
      filePath: filePath,
      title: file.uri.pathSegments.last,
      sheets: [sheet],
      lastModified: file.statSync().modified,
      isDirty: false,
    );
  }

  static String exportToCsv(SheetModel sheet) {
    final List<List<dynamic>> rows = [];
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

    for (var r = 0; r <= maxR; r++) {
      final List<dynamic> row = [];
      for (var c = 0; c <= maxC; c++) {
        final cell = sheet.getCell(r, c);
        row.add(cell.calculatedValue.isNotEmpty ? cell.calculatedValue : cell.value);
      }
      rows.add(row);
    }

    return const ListToCsvConverter().convert(rows);
  }
}
