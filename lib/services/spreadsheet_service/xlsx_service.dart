import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart' show TextAlign;
import 'package:xml/xml.dart';
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

    // Also decode ZIP archive to parse OpenXML mergeCells directly as a fail-safe
    Archive? archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {}

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

          final cellStyle = cellData.cellStyle;
          final isBold = cellStyle?.isBold ?? false;
          final isItalic = cellStyle?.isItalic ?? false;
          TextAlign align = TextAlign.left;
          if (cellStyle != null) {
            if (cellStyle.horizontalAlignment == HorizontalAlign.Center) {
              align = TextAlign.center;
            } else if (cellStyle.horizontalAlignment == HorizontalAlign.Right) {
              align = TextAlign.right;
            }
          }

          if (strVal.isNotEmpty || formula != null || isBold || isItalic) {
            sheet.setCell(
              r,
              c,
              CellModel(
                value: strVal,
                formula: formula,
                calculatedValue: strVal,
                isBold: isBold,
                isItalic: isItalic,
                align: align,
              ),
            );
          }
        }
      }

      // ── 1. Apply merged cells from excel package spannedItems
      for (final spanRef in table.spannedItems) {
        _applyMergeRange(sheet, spanRef);
      }

      // ── 2. Fallback: Parse <mergeCells> from worksheet XML in archive
      if (archive != null) {
        _parseMergeCellsFromArchive(archive, sheet, sheets.length + 1);
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

  /// Parses merged cell ranges (e.g. "A1:E1") and configures master/child cells
  static void _applyMergeRange(SheetModel sheet, String rangeRef) {
    final parts = rangeRef.split(':');
    if (parts.length != 2) return;

    final start = parseCellCoord(parts[0]);
    final end = parseCellCoord(parts[1]);
    if (start == null || end == null) return;

    final startRow = start.$1;
    final startCol = start.$2;
    final endRow = end.$1;
    final endCol = end.$2;

    final minRow = startRow < endRow ? startRow : endRow;
    final maxRow = startRow > endRow ? startRow : endRow;
    final minCol = startCol < endCol ? startCol : endCol;
    final maxCol = startCol > endCol ? startCol : endCol;

    final colSpan = maxCol - minCol + 1;
    final rowSpan = maxRow - minRow + 1;

    // Master cell at top-left
    final master = sheet.getCell(minRow, minCol);
    sheet.setCell(
      minRow,
      minCol,
      master.copyWith(
        colSpan: colSpan,
        rowSpan: rowSpan,
        isMergedChild: false,
      ),
    );

    // Child cells inside the merge box are hidden under the master
    for (var r = minRow; r <= maxRow; r++) {
      for (var c = minCol; c <= maxCol; c++) {
        if (r != minRow || c != minCol) {
          final child = sheet.getCell(r, c);
          sheet.setCell(
            r,
            c,
            child.copyWith(
              isMergedChild: true,
              colSpan: 1,
              rowSpan: 1,
            ),
          );
        }
      }
    }
  }

  /// Converts a cell reference string like "A1", "E5", "AA10" into 0-indexed (row, col)
  static (int, int)? parseCellCoord(String cellRef) {
    final match = RegExp(r'^([A-Za-z]+)(\d+)$').firstMatch(cellRef.trim());
    if (match == null) return null;
    final colStr = match.group(1)!.toUpperCase();
    final rowStr = match.group(2)!;

    var col = 0;
    for (var i = 0; i < colStr.length; i++) {
      col = col * 26 + (colStr.codeUnitAt(i) - 64);
    }
    col -= 1; // 0-indexed

    final row = (int.tryParse(rowStr) ?? 1) - 1; // 0-indexed
    return (row, col);
  }

  /// Fallback archive mergeCells reader
  static void _parseMergeCellsFromArchive(Archive archive, SheetModel sheet, int sheetIndex) {
    try {
      // Find worksheet XML file by index or name
      ArchiveFile? sheetXmlFile = archive.findFile('xl/worksheets/sheet$sheetIndex.xml');
      if (sheetXmlFile == null) {
        // Search by filename pattern
        for (final f in archive.files) {
          if (f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml')) {
            sheetXmlFile = f;
            break;
          }
        }
      }

      if (sheetXmlFile != null) {
        final xmlStr = utf8.decode(sheetXmlFile.content as List<int>);
        final doc = XmlDocument.parse(xmlStr);
        for (final mergeEl in doc.findAllElements('mergeCell')) {
          final ref = mergeEl.getAttribute('ref');
          if (ref != null && ref.isNotEmpty) {
            _applyMergeRange(sheet, ref);
          }
        }
      }
    } catch (_) {}
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
        final coord = parseCellCoord(key);
        if (coord == null) continue;

        final rowIndex = coord.$1;
        final colIndex = coord.$2;

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

        // Apply merge if master cell has spans
        if (cellModel.colSpan > 1 || cellModel.rowSpan > 1) {
          final endCellIndex = CellIndex.indexByColumnRow(
            columnIndex: colIndex + cellModel.colSpan - 1,
            rowIndex: rowIndex + cellModel.rowSpan - 1,
          );
          sheet.merge(cellIndex, endCellIndex);
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

