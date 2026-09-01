import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../../models/spreadsheet_model.dart';
import 'formula_engine.dart';

class XlsxService {
  static Future<WorkbookModel> importXlsx(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return WorkbookModel.empty();
    }

    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    final List<SheetModel> sheets = [];

    for (final tableName in excel.tables.keys) {
      final table = excel.tables[tableName];
      if (table == null) continue;

      final sheet = SheetModel(
        name: tableName,
        rowCount: table.maxRows > 20 ? table.maxRows + 10 : 50,
        columnCount: table.maxColumns > 10 ? table.maxColumns + 5 : 26,
      );

      for (var r = 0; r < table.maxRows; r++) {
        final row = table.rows[r];
        for (var c = 0; c < row.length; c++) {
          final cellData = row[c];
          if (cellData == null) continue;

          final val = cellData.value;
          String strVal = '';
          String? formula;

          if (val is TextCellValue) {
            strVal = val.value.text ?? '';
          } else if (val is FormulaCellValue) {
            formula = val.formula;
            strVal = formula;
          } else if (val is IntCellValue) {
            strVal = val.value.toString();
          } else if (val is DoubleCellValue) {
            strVal = val.value.toString();
          } else if (val is BoolCellValue) {
            strVal = val.value ? 'TRUE' : 'FALSE';
          } else if (val != null) {
            strVal = val.toString();
          }

          if (strVal.isNotEmpty || formula != null) {
            sheet.setCell(
              r,
              c,
              CellModel(
                value: strVal,
                formula: formula,
                calculatedValue: strVal,
              ),
            );
          }
        }
      }

      FormulaEngine.recalculateSheet(sheet);
      sheets.add(sheet);
    }

    if (sheets.isEmpty) {
      sheets.add(SheetModel(name: 'Sheet1'));
    }

    return WorkbookModel(
      filePath: filePath,
      title: file.uri.pathSegments.last,
      sheets: sheets,
      lastModified: file.statSync().modified,
      isDirty: false,
    );
  }

  static Uint8List exportToXlsx(WorkbookModel workbook) {
    final excel = Excel.createExcel();

    // Remove default sheet
    final defaultSheetName = excel.getDefaultSheet();

    for (final sheetModel in workbook.sheets) {
      final sheet = excel[sheetModel.name];

      for (final entry in sheetModel.cells.entries) {
        final key = entry.key;
        final cellModel = entry.value;
        final colLetter = key.replaceAll(RegExp(r'[0-9]'), '');
        final rowNum = int.parse(key.replaceAll(RegExp(r'[A-Za-z]'), ''));

        final colIndex = colLetter.codeUnitAt(0) - 65;
        final rowIndex = rowNum - 1;

        final cellIndex = CellIndex.indexByColumnRow(
          columnIndex: colIndex,
          rowIndex: rowIndex,
        );

        if (cellModel.formula != null && cellModel.formula!.startsWith('=')) {
          sheet.cell(cellIndex).value = FormulaCellValue(cellModel.formula!);
        } else {
          final numVal = double.tryParse(cellModel.value);
          if (numVal != null) {
            if (numVal % 1 == 0) {
              sheet.cell(cellIndex).value = IntCellValue(numVal.toInt());
            } else {
              sheet.cell(cellIndex).value = DoubleCellValue(numVal);
            }
          } else {
            sheet.cell(cellIndex).value = TextCellValue(cellModel.value);
          }
        }
      }
    }

    if (defaultSheetName != null && !workbook.sheets.any((s) => s.name == defaultSheetName)) {
      excel.delete(defaultSheetName);
    }

    final encoded = excel.save();
    return Uint8List.fromList(encoded ?? []);
  }
}
