import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../shared/widgets/tk_dialogs.dart';
import '../pdf/pdf_viewer_screen.dart';
import 'writer_controller.dart';
import 'writer_toolbar.dart';

class WriterScreen extends StatelessWidget {
  final String? filePath;
  final String? initialTitle;

  const WriterScreen({
    super.key,
    this.filePath,
    this.initialTitle,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WriterController()..init(filePath: filePath, initialTitle: initialTitle),
      child: const _WriterView(),
    );
  }
}

class _WriterView extends StatelessWidget {
  const _WriterView();

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<WriterController>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (controller.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final doc = controller.document;

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
                doc?.title ?? 'Document',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              _buildSaveStatusWidget(controller),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              tooltip: 'Undo',
              onPressed: controller.undo,
            ),
            IconButton(
              icon: const Icon(Icons.redo_rounded),
              tooltip: 'Redo',
              onPressed: controller.redo,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (action) async {
                if (action == 'save') {
                  final ok = await controller.manualSave();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? 'Document saved ✓' : 'Failed to save document')),
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
                  await controller.printDocument();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'save',
                  child: Row(
                    children: [
                      Icon(Icons.save_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Save Now'),
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
                      Text('Print Document'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Container(
                color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 500),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 40 : 10),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: QuillEditor.basic(
                      controller: controller.quillController,
                    ),
                  ),
                ),
              ),
            ),
            // Formatting Toolbar
            WriterToolbar(controller: controller.quillController),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveStatusWidget(WriterController controller) {
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
