import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/spreadsheet_model.dart';
import 'sheets_controller.dart';

class SheetsToolbar extends StatelessWidget {
  final SheetsController controller;

  const SheetsToolbar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cell = controller.selectedCell;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              // Bold
              IconButton(
                icon: Icon(
                  Icons.format_bold_rounded,
                  color: cell.isBold ? AppTheme.sheetGreen : null,
                ),
                tooltip: 'Bold',
                onPressed: controller.toggleBold,
              ),
              // Italic
              IconButton(
                icon: Icon(
                  Icons.format_italic_rounded,
                  color: cell.isItalic ? AppTheme.sheetGreen : null,
                ),
                tooltip: 'Italic',
                onPressed: controller.toggleItalic,
              ),
              _buildDivider(isDark),

              // Align Left
              IconButton(
                icon: Icon(
                  Icons.format_align_left_rounded,
                  color: cell.align == TextAlign.left ? AppTheme.sheetGreen : null,
                ),
                tooltip: 'Align Left',
                onPressed: () => controller.setAlignment(TextAlign.left),
              ),
              // Align Center
              IconButton(
                icon: Icon(
                  Icons.format_align_center_rounded,
                  color: cell.align == TextAlign.center ? AppTheme.sheetGreen : null,
                ),
                tooltip: 'Align Center',
                onPressed: () => controller.setAlignment(TextAlign.center),
              ),
              // Align Right
              IconButton(
                icon: Icon(
                  Icons.format_align_right_rounded,
                  color: cell.align == TextAlign.right ? AppTheme.sheetGreen : null,
                ),
                tooltip: 'Align Right',
                onPressed: () => controller.setAlignment(TextAlign.right),
              ),
              // Merge / Unmerge Cells
              IconButton(
                icon: Icon(
                  cell.colSpan > 1 || cell.rowSpan > 1
                      ? Icons.call_split_rounded
                      : Icons.call_merge_rounded,
                  color: (cell.colSpan > 1 || cell.rowSpan > 1) ? AppTheme.sheetGreen : null,
                ),
                tooltip: cell.colSpan > 1 || cell.rowSpan > 1 ? 'Unmerge Cell' : 'Merge Columns',
                onPressed: () {
                  final row = controller.selectedRow;
                  final col = controller.selectedCol;
                  if (cell.colSpan > 1 || cell.rowSpan > 1) {
                    controller.unmergeCell(row, col);
                  } else {
                    // Default merge 2 columns rightward
                    controller.mergeCells(row, col, row, col + 1);
                  }
                },
              ),
              _buildDivider(isDark),

              // Quick AutoSum button
              TextButton.icon(
                icon: const Icon(Icons.calculate_outlined, size: 18, color: AppTheme.sheetGreen),
                label: const Text('AutoSum', style: TextStyle(color: AppTheme.sheetGreen, fontWeight: FontWeight.bold)),
                onPressed: () {
                  final row = controller.selectedRow;
                  final col = controller.selectedCol;
                  if (row > 0) {
                    final startKey = SheetModel.getCellKey(0, col);
                    final endKey = SheetModel.getCellKey(row - 1, col);
                    final formula = '=SUM($startKey:$endKey)';
                    controller.setCellValue(formula);
                    controller.formulaInputController.text = formula;
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
    );
  }
}
