import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../shared/widgets/tk_dialogs.dart';
import '../pdf/pdf_viewer_screen.dart';
import '../writer/writer_controller.dart';
import 'presentation_mode.dart';
import 'slide_canvas.dart';
import 'slide_thumbnail_strip.dart';
import 'slide_toolbar.dart';
import 'slides_controller.dart';

class SlidesScreen extends StatelessWidget {
  final String? filePath;
  final String? initialTitle;

  const SlidesScreen({
    super.key,
    this.filePath,
    this.initialTitle,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SlidesController()..init(filePath: filePath, initialTitle: initialTitle),
      child: const _SlidesView(),
    );
  }
}

class _SlidesView extends StatelessWidget {
  const _SlidesView();

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<SlidesController>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (controller.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pres = controller.presentation;

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
                pres?.title ?? 'Presentation',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              _buildSaveStatusWidget(controller),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded, color: AppTheme.slideOrange, size: 28),
              tooltip: 'Start Presentation',
              onPressed: () {
                if (pres != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PresentationModeScreen(
                        presentation: pres,
                        initialSlideIndex: controller.activeSlideIndex,
                      ),
                    ),
                  );
                }
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (action) async {
                if (action == 'save') {
                  final ok = await controller.manualSave();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? 'Presentation saved ✓' : 'Failed to save')),
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
                  await controller.printPresentation();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'save',
                  child: Row(
                    children: [
                      Icon(Icons.save_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Save Presentation'),
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
                      Text('Print Slides'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // Slide Canvas Viewport
            Expanded(
              child: Container(
                color: isDark ? const Color(0xFF090D16) : const Color(0xFFE2E8F0),
                child: SlideCanvas(controller: controller),
              ),
            ),

            // Slide Toolbar
            SlideToolbar(controller: controller),

            // Slide Thumbnails Strip
            SlideThumbnailStrip(controller: controller),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveStatusWidget(SlidesController controller) {
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
