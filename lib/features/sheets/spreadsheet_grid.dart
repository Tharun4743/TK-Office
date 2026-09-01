import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'sheets_controller.dart';

class SpreadsheetGrid extends StatefulWidget {
  final SheetsController controller;

  const SpreadsheetGrid({
    super.key,
    required this.controller,
  });

  @override
  State<SpreadsheetGrid> createState() => _SpreadsheetGridState();
}

class _SpreadsheetGridState extends State<SpreadsheetGrid> {
  final ScrollController _horizontalHeaderController = ScrollController();
  final ScrollController _horizontalContentController = ScrollController();
  final ScrollController _verticalHeaderController = ScrollController();
  final ScrollController _verticalContentController = ScrollController();

  static const double cellWidth = 90.0;
  static const double cellHeight = 36.0;
  static const double headerColWidth = 44.0;
  static const double headerRowHeight = 32.0;

  @override
  void initState() {
    super.initState();
    _horizontalContentController.addListener(() {
      if (_horizontalHeaderController.hasClients &&
          _horizontalHeaderController.offset != _horizontalContentController.offset) {
        _horizontalHeaderController.jumpTo(_horizontalContentController.offset);
      }
    });

    _verticalContentController.addListener(() {
      if (_verticalHeaderController.hasClients &&
          _verticalHeaderController.offset != _verticalContentController.offset) {
        _verticalHeaderController.jumpTo(_verticalContentController.offset);
      }
    });
  }

  @override
  void dispose() {
    _horizontalHeaderController.dispose();
    _horizontalContentController.dispose();
    _verticalHeaderController.dispose();
    _verticalContentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheet = widget.controller.activeSheet;

    if (sheet == null) {
      return const Center(child: Text('No active sheet'));
    }

    final gridBorderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final headerBgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    return Column(
      children: [
        // Top Header Row (Corner box + Column letters A, B, C...)
        Row(
          children: [
            // Top Left Corner
            Container(
              width: headerColWidth,
              height: headerRowHeight,
              decoration: BoxDecoration(
                color: headerBgColor,
                border: Border(
                  right: BorderSide(color: gridBorderColor),
                  bottom: BorderSide(color: gridBorderColor),
                ),
              ),
              child: const Icon(Icons.grid_4x4_rounded, size: 16, color: Colors.grey),
            ),

            // Column Letters Header (Horizontal scroll)
            Expanded(
              child: SizedBox(
                height: headerRowHeight,
                child: ListView.builder(
                  controller: _horizontalHeaderController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  itemCount: sheet.columnCount,
                  itemBuilder: (context, c) {
                    final isColSelected = c == widget.controller.selectedCol;
                    final letter = String.fromCharCode(65 + c);
                    return Container(
                      width: cellWidth,
                      height: headerRowHeight,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isColSelected
                            ? AppTheme.sheetGreen.withAlpha(isDark ? 80 : 40)
                            : headerBgColor,
                        border: Border(
                          right: BorderSide(color: gridBorderColor),
                          bottom: BorderSide(color: gridBorderColor),
                        ),
                      ),
                      child: Text(
                        letter,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isColSelected ? FontWeight.bold : FontWeight.w600,
                          color: isColSelected ? AppTheme.sheetGreen : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),

        // Main Grid Body (Row numbers + Cell Matrix)
        Expanded(
          child: Row(
            children: [
              // Row Numbers Header (Vertical scroll)
              SizedBox(
                width: headerColWidth,
                child: ListView.builder(
                  controller: _verticalHeaderController,
                  scrollDirection: Axis.vertical,
                  physics: const ClampingScrollPhysics(),
                  itemCount: sheet.rowCount,
                  itemBuilder: (context, r) {
                    final isRowSelected = r == widget.controller.selectedRow;
                    return Container(
                      width: headerColWidth,
                      height: cellHeight,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isRowSelected
                            ? AppTheme.sheetGreen.withAlpha(isDark ? 80 : 40)
                            : headerBgColor,
                        border: Border(
                          right: BorderSide(color: gridBorderColor),
                          bottom: BorderSide(color: gridBorderColor),
                        ),
                      ),
                      child: Text(
                        '${r + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isRowSelected ? FontWeight.bold : FontWeight.w600,
                          color: isRowSelected ? AppTheme.sheetGreen : null,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Cells Viewport (Bi-directional scroll)
              Expanded(
                child: SingleChildScrollView(
                  controller: _horizontalContentController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: sheet.columnCount * cellWidth,
                    child: ListView.builder(
                      controller: _verticalContentController,
                      scrollDirection: Axis.vertical,
                      physics: const ClampingScrollPhysics(),
                      itemCount: sheet.rowCount,
                      itemBuilder: (context, r) {
                        return SizedBox(
                          height: cellHeight,
                          child: Row(
                            children: List.generate(sheet.columnCount, (c) {
                              final isSelected = r == widget.controller.selectedRow &&
                                  c == widget.controller.selectedCol;
                              final cell = sheet.getCell(r, c);
                              final displayText = cell.calculatedValue.isNotEmpty
                                  ? cell.calculatedValue
                                  : cell.value;

                              return GestureDetector(
                                onTap: () => widget.controller.selectCell(r, c),
                                child: Container(
                                  width: cellWidth,
                                  height: cellHeight,
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  alignment: _getAlignment(cell.align),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.sheetGreen.withAlpha(isDark ? 50 : 25)
                                        : (cell.bgColor ?? (isDark ? const Color(0xFF1E293B) : Colors.white)),
                                    border: isSelected
                                        ? Border.all(color: AppTheme.sheetGreen, width: 2)
                                        : Border(
                                            right: BorderSide(color: gridBorderColor, width: 0.8),
                                            bottom: BorderSide(color: gridBorderColor, width: 0.8),
                                          ),
                                  ),
                                  child: Text(
                                    displayText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: cell.isBold ? FontWeight.bold : FontWeight.normal,
                                      fontStyle: cell.isItalic ? FontStyle.italic : FontStyle.normal,
                                      color: cell.textColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Alignment _getAlignment(TextAlign align) {
    switch (align) {
      case TextAlign.left:
      case TextAlign.start:
        return Alignment.centerLeft;
      case TextAlign.center:
        return Alignment.center;
      case TextAlign.right:
      case TextAlign.end:
        return Alignment.centerRight;
      case TextAlign.justify:
        return Alignment.centerLeft;
    }
  }
}
