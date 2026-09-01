import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'sheets_controller.dart';

class FormulaBar extends StatelessWidget {
  final SheetsController controller;

  const FormulaBar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          // Cell Coordinate Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.sheetGreen.withAlpha(isDark ? 50 : 25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.sheetGreen.withAlpha(100),
              ),
            ),
            child: Text(
              controller.selectedCellKey,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppTheme.sheetGreen,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // fx symbol
          Text(
            'fx',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyMedium?.color?.withAlpha(150),
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 8),

          // Formula Input Field
          Expanded(
            child: TextField(
              controller: controller.formulaInputController,
              onChanged: (text) => controller.setCellValue(text),
              decoration: const InputDecoration(
                hintText: 'Enter text or formula (=SUM, =AVG...)',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),

          // Quick Formula Helper Button
          IconButton(
            icon: const Icon(Icons.functions_rounded, size: 20),
            tooltip: 'Insert Formula',
            onPressed: () => _showFormulaSelector(context),
          ),
        ],
      ),
    );
  }

  void _showFormulaSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Select Formula',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  _buildFormulaItem(ctx, 'SUM', '=SUM(A1:A5)', 'Calculate total sum of numbers'),
                  _buildFormulaItem(ctx, 'AVERAGE', '=AVERAGE(A1:A5)', 'Calculate average of numbers'),
                  _buildFormulaItem(ctx, 'MIN', '=MIN(A1:A5)', 'Find minimum value'),
                  _buildFormulaItem(ctx, 'MAX', '=MAX(A1:A5)', 'Find maximum value'),
                  _buildFormulaItem(ctx, 'COUNT', '=COUNT(A1:A5)', 'Count cells with numbers'),
                  _buildFormulaItem(ctx, 'COUNTA', '=COUNTA(A1:A5)', 'Count non-empty cells'),
                  _buildFormulaItem(ctx, 'IF', '=IF(A1>50, "Pass", "Fail")', 'Logical condition check'),
                  _buildFormulaItem(ctx, 'CONCAT', '=CONCAT(A1, " ", B1)', 'Join text strings'),
                  _buildFormulaItem(ctx, 'ROUND', '=ROUND(A1, 2)', 'Round to specified decimals'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulaItem(BuildContext context, String name, String template, String desc) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.sheetGreen.withAlpha(30),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.functions_rounded, color: AppTheme.sheetGreen, size: 20),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
      trailing: Text(
        template,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey),
      ),
      onTap: () {
        Navigator.pop(context);
        controller.setCellValue(template);
        controller.formulaInputController.text = template;
      },
    );
  }
}
