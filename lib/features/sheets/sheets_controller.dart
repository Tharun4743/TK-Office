import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_constants.dart';
import '../../models/spreadsheet_model.dart';
import '../../services/file_service/file_service.dart';
import '../../services/spreadsheet_service/formula_engine.dart';
import '../../services/spreadsheet_service/spreadsheet_service.dart';
import '../writer/writer_controller.dart';

class SheetsController extends ChangeNotifier {
  final SpreadsheetService _spreadsheetService = SpreadsheetService();
  final FileService _fileService = FileService();

  WorkbookModel? _workbook;
  bool _isLoading = true;
  SaveStatus _saveStatus = SaveStatus.idle;
  Timer? _debounceTimer;

  int _selectedRow = 0;
  int _selectedCol = 0;
  final TextEditingController formulaInputController = TextEditingController();

  WorkbookModel? get workbook => _workbook;
  bool get isLoading => _isLoading;
  SaveStatus get saveStatus => _saveStatus;
  int get selectedRow => _selectedRow;
  int get selectedCol => _selectedCol;
  bool get isDirty => _workbook?.isDirty ?? false;

  SheetModel? get activeSheet => _workbook?.activeSheet;
  CellModel get selectedCell => activeSheet?.getCell(_selectedRow, _selectedCol) ?? CellModel();
  String get selectedCellKey => SheetModel.getCellKey(_selectedRow, _selectedCol);

  Future<void> init({String? filePath, String? initialTitle}) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (filePath != null) {
        _workbook = await _spreadsheetService.loadWorkbook(filePath);
        await _fileService.recordRecentFile(filePath);
      } else {
        _workbook = await _spreadsheetService.createNewWorkbook(
          title: initialTitle ?? 'Untitled Spreadsheet',
        );
      }

      _syncFormulaInput();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectCell(int row, int col) {
    _selectedRow = row;
    _selectedCol = col;
    _syncFormulaInput();
    notifyListeners();
  }

  void _syncFormulaInput() {
    final cell = selectedCell;
    formulaInputController.text = cell.formula ?? cell.value;
  }

  void setCellValue(String text) {
    if (activeSheet == null) return;

    final isFormula = text.startsWith('=');
    final currentCell = selectedCell;

    final updated = currentCell.copyWith(
      value: isFormula ? currentCell.value : text,
      formula: isFormula ? text : null,
      calculatedValue: isFormula ? FormulaEngine.evaluate(text, activeSheet!) : text,
    );

    activeSheet!.setCell(_selectedRow, _selectedCol, updated);
    FormulaEngine.recalculateSheet(activeSheet!);
    _markDirty();
  }

  void toggleBold() {
    if (activeSheet == null) return;
    final current = selectedCell;
    activeSheet!.setCell(
      _selectedRow,
      _selectedCol,
      current.copyWith(isBold: !current.isBold),
    );
    _markDirty();
  }

  void toggleItalic() {
    if (activeSheet == null) return;
    final current = selectedCell;
    activeSheet!.setCell(
      _selectedRow,
      _selectedCol,
      current.copyWith(isItalic: !current.isItalic),
    );
    _markDirty();
  }

  void setAlignment(TextAlign align) {
    if (activeSheet == null) return;
    final current = selectedCell;
    activeSheet!.setCell(
      _selectedRow,
      _selectedCol,
      current.copyWith(align: align),
    );
    _markDirty();
  }

  void mergeCells(int startRow, int startCol, int endRow, int endCol) {
    if (activeSheet == null) return;
    final r1 = startRow < endRow ? startRow : endRow;
    final r2 = startRow > endRow ? startRow : endRow;
    final c1 = startCol < endCol ? startCol : endCol;
    final c2 = startCol > endCol ? startCol : endCol;

    final colSpan = c2 - c1 + 1;
    final rowSpan = r2 - r1 + 1;

    final master = activeSheet!.getCell(r1, c1);
    activeSheet!.setCell(
      r1,
      c1,
      master.copyWith(
        colSpan: colSpan,
        rowSpan: rowSpan,
        isMergedChild: false,
        align: TextAlign.center,
      ),
    );

    for (var r = r1; r <= r2; r++) {
      for (var c = c1; c <= c2; c++) {
        if (r != r1 || c != c1) {
          final child = activeSheet!.getCell(r, c);
          activeSheet!.setCell(
            r,
            c,
            child.copyWith(isMergedChild: true, colSpan: 1, rowSpan: 1),
          );
        }
      }
    }
    _markDirty();
  }

  void unmergeCell(int row, int col) {
    if (activeSheet == null) return;
    final master = activeSheet!.getCell(row, col);
    if (master.colSpan <= 1 && master.rowSpan <= 1) return;

    final colSpan = master.colSpan;
    final rowSpan = master.rowSpan;

    activeSheet!.setCell(
      row,
      col,
      master.copyWith(colSpan: 1, rowSpan: 1, isMergedChild: false),
    );

    for (var r = row; r < row + rowSpan; r++) {
      for (var c = col; c < col + colSpan; c++) {
        if (r != row || c != col) {
          final child = activeSheet!.getCell(r, c);
          activeSheet!.setCell(
            r,
            c,
            child.copyWith(isMergedChild: false, colSpan: 1, rowSpan: 1),
          );
        }
      }
    }
    _markDirty();
  }

  void switchSheet(int index) {
    if (_workbook == null || index < 0 || index >= _workbook!.sheets.length) return;
    _workbook!.activeSheetIndex = index;
    _selectedRow = 0;
    _selectedCol = 0;
    _syncFormulaInput();
    notifyListeners();
  }

  void addSheet(String name) {
    if (_workbook == null) return;
    _workbook!.sheets.add(SheetModel(name: name));
    _workbook!.activeSheetIndex = _workbook!.sheets.length - 1;
    _markDirty();
  }

  void renameSheet(int index, String newName) {
    if (_workbook == null || index < 0 || index >= _workbook!.sheets.length) return;
    _workbook!.sheets[index].name = newName;
    _markDirty();
  }

  void deleteSheet(int index) {
    if (_workbook == null || _workbook!.sheets.length <= 1) return;
    _workbook!.sheets.removeAt(index);
    if (_workbook!.activeSheetIndex >= _workbook!.sheets.length) {
      _workbook!.activeSheetIndex = _workbook!.sheets.length - 1;
    }
    _markDirty();
  }

  void _markDirty() {
    if (_workbook == null) return;
    _workbook!.isDirty = true;
    _saveStatus = SaveStatus.idle;
    notifyListeners();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: AppConstants.autosaveDebounceMs),
      () => autoSave(),
    );
  }

  Future<void> autoSave() async {
    if (_workbook == null || !_workbook!.isDirty) return;

    _saveStatus = SaveStatus.saving;
    notifyListeners();

    try {
      await _spreadsheetService.saveWorkbook(_workbook!);
      _saveStatus = SaveStatus.saved;
      notifyListeners();

      Future.delayed(const Duration(seconds: 2), () {
        if (_saveStatus == SaveStatus.saved) {
          _saveStatus = SaveStatus.idle;
          notifyListeners();
        }
      });
    } catch (_) {
      _saveStatus = SaveStatus.error;
      notifyListeners();
    }
  }

  Future<bool> manualSave() async {
    if (_workbook == null) return false;
    _saveStatus = SaveStatus.saving;
    notifyListeners();

    try {
      await _spreadsheetService.saveWorkbook(_workbook!);
      if (_workbook!.filePath != null) {
        await _fileService.recordRecentFile(_workbook!.filePath!);
      }
      _saveStatus = SaveStatus.saved;
      notifyListeners();
      return true;
    } catch (_) {
      _saveStatus = SaveStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<String?> exportPdf() async {
    if (_workbook == null) return null;
    await manualSave();
    return await _spreadsheetService.exportToPdf(_workbook!);
  }

  Future<void> printWorkbook() async {
    if (_workbook == null) return;
    await manualSave();
    await _spreadsheetService.printWorkbook(_workbook!);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    formulaInputController.dispose();
    super.dispose();
  }
}
