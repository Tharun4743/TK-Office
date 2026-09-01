import 'package:flutter/material.dart';

class CellModel {
  String value;
  String? formula;
  String calculatedValue;
  bool isBold;
  bool isItalic;
  Color? textColor;
  Color? bgColor;
  TextAlign align;
  String numberFormat;

  CellModel({
    this.value = '',
    this.formula,
    String? calculatedValue,
    this.isBold = false,
    this.isItalic = false,
    this.textColor,
    this.bgColor,
    this.align = TextAlign.left,
    this.numberFormat = 'General',
  }) : calculatedValue = calculatedValue ?? value;

  CellModel copyWith({
    String? value,
    String? formula,
    String? calculatedValue,
    bool? isBold,
    bool? isItalic,
    Color? textColor,
    Color? bgColor,
    TextAlign? align,
    String? numberFormat,
  }) {
    return CellModel(
      value: value ?? this.value,
      formula: formula ?? this.formula,
      calculatedValue: calculatedValue ?? this.calculatedValue,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      textColor: textColor ?? this.textColor,
      bgColor: bgColor ?? this.bgColor,
      align: align ?? this.align,
      numberFormat: numberFormat ?? this.numberFormat,
    );
  }
}

class SheetModel {
  String name;
  int rowCount;
  int columnCount;
  final Map<String, CellModel> cells;

  SheetModel({
    required this.name,
    this.rowCount = 50,
    this.columnCount = 26,
    Map<String, CellModel>? cells,
  }) : cells = cells ?? {};

  static String getCellKey(int row, int col) {
    final colLetter = String.fromCharCode(65 + col);
    return '$colLetter${row + 1}';
  }

  CellModel getCell(int row, int col) {
    final key = getCellKey(row, col);
    return cells[key] ?? CellModel();
  }

  void setCell(int row, int col, CellModel cell) {
    final key = getCellKey(row, col);
    cells[key] = cell;
    if (row >= rowCount) rowCount = row + 10;
    if (col >= columnCount) columnCount = col + 5;
  }
}

class WorkbookModel {
  String? filePath;
  String title;
  List<SheetModel> sheets;
  int activeSheetIndex;
  DateTime lastModified;
  bool isDirty;

  WorkbookModel({
    this.filePath,
    required this.title,
    required this.sheets,
    this.activeSheetIndex = 0,
    required this.lastModified,
    this.isDirty = false,
  });

  SheetModel get activeSheet => sheets[activeSheetIndex];

  factory WorkbookModel.empty({String title = 'Untitled Workbook'}) {
    return WorkbookModel(
      title: title,
      sheets: [
        SheetModel(name: 'Sheet1'),
      ],
      lastModified: DateTime.now(),
      isDirty: false,
    );
  }
}
