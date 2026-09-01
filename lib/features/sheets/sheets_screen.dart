import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../shared/widgets/tk_dialogs.dart';
import '../pdf/pdf_viewer_screen.dart';
import '../writer/writer_controller.dart';
import 'formula_bar.dart';
import 'sheets_controller.dart';
import 'sheets_toolbar.dart';
import 'spreadsheet_grid.dart';

class SheetsScreen extends StatelessWidget {
  final String? filePath;
  final String? initialTitle;

  const SheetsScreen({
    super.key,
    this.filePath,
    this.initialTitle,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SheetsController()..init(filePath: filePath, initialTitle: initialTitle),
      child: const _SheetsView(),
    );
  }
}

class _SheetsView extends StatelessWidget {
  const _SheetsView();

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<SheetsController>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (controller.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final wb = controller.workbook;

    return PopScope(
      canPop: !controller.isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldDiscard = await TKDialogs.confirmDiscardChanges(context: context);
        if (shouldDiscard && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              if (controller.isDirty) {
                final shouldDiscard = await TKDialogs.confirmDiscardChanges(context: context);
                if (shouldDiscard && context.mounted) {
                  Navigator.of(context).pop();
                }
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                wb?.title ?? 'Spreadsheet',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              _buildSaveStatusWidget(controller),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (action) async {
                if (action == 'save') {
                  final ok = await controller.manualSave();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? 'Workbook saved ✓' : 'Failed to save workbook')),
                    );
                  }
                } else if (action == 'export_pdf') {
                  final pdfPath = await controller.exportPdf();
                  if (pdfPath != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Exported to PDF ✓')),
                    );
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PdfViewerScreen(filePath: pdfPath),
                      ),
                    );
                  }
                } else if (action == 'print') {
                  await controller.printWorkbook();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'save',
                  child: Row(
                    children: [
                      Icon(Icons.save_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Save Workbook'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export_pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf_outlined, size: 20, color: AppTheme.pdfRed),
                      SizedBox(width: 12),
                      Text('Export to PDF'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'print',
                  child: Row(
                    children: [
                      Icon(Icons.print_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Print Workbook'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // Formula Input Bar
            FormulaBar(controller: controller),

            // Spreadsheet 2D Grid
            Expanded(
              child: SpreadsheetGrid(controller: controller),
            ),

            // Formatting Toolbar
            SheetsToolbar(controller: controller),

            // Sheet Tabs Bottom Bar
            _buildSheetTabBar(context, controller, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetTabBar(BuildContext context, SheetsController controller, bool isDark) {
    final wb = controller.workbook;
    if (wb == null) return const SizedBox.shrink();

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: wb.sheets.length,
              itemBuilder: (ctx, index) {
                final sheet = wb.sheets[index];
                final isActive = index == wb.activeSheetIndex;

                return GestureDetector(
                  onTap: () => controller.switchSheet(index),
                  onLongPress: () => _showSheetOptions(context, controller, index, sheet.name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isActive
                          ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                          : Colors.transparent,
                      border: Border(
                        top: BorderSide(
                          color: isActive ? AppTheme.sheetGreen : Colors.transparent,
                          width: 3,
                        ),
                        right: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Text(
                      sheet.name,
                      style: TextStyle(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                        color: isActive ? AppTheme.sheetGreen : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 20),
            tooltip: 'Add Sheet',
            onPressed: () async {
              final newName = await TKDialogs.showNameInputDialog(
                context: context,
                title: 'Add New Sheet',
                initialValue: 'Sheet${wb.sheets.length + 1}',
                actionLabel: 'Add',
              );
              if (newName != null) {
                controller.addSheet(newName);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showSheetOptions(BuildContext context, SheetsController controller, int index, String currentName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Text(
                'Sheet: $currentName',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename Sheet'),
              onTap: () async {
                Navigator.pop(ctx);
                final newName = await TKDialogs.showNameInputDialog(
                  context: context,
                  title: 'Rename Sheet',
                  initialValue: currentName,
                  actionLabel: 'Rename',
                );
                if (newName != null) {
                  controller.renameSheet(index, newName);
                }
              },
            ),
            if (controller.workbook != null && controller.workbook!.sheets.length > 1)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Delete Sheet', style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await TKDialogs.confirmDelete(
                    context: context,
                    itemName: currentName,
                  );
                  if (confirm) {
                    controller.deleteSheet(index);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveStatusWidget(SheetsController controller) {
    switch (controller.saveStatus) {
      case SaveStatus.saving:
        return const Text(
          'Saving...',
          style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w500),
        );
      case SaveStatus.saved:
        return const Text(
          'Saved ✓',
          style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
        );
      case SaveStatus.error:
        return const Text(
          'Error saving',
          style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
        );
      case SaveStatus.idle:
        return Text(
          controller.isDirty ? 'Unsaved changes' : 'All changes saved',
          style: TextStyle(
            fontSize: 11,
            color: controller.isDirty ? Colors.orange : Colors.grey,
          ),
        );
    }
  }
}
