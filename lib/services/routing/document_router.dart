import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../features/conversion_center/image_to_pdf_screen.dart';
import '../../features/pdf/pdf_viewer_screen.dart';
import '../../features/sheets/sheets_screen.dart';
import '../../features/slides/slides_screen.dart';
import '../../features/writer/writer_screen.dart';
import '../../services/file_service/file_service.dart';
import '../../services/storage_service/local_storage_service.dart';
import '../../utils/file_utils.dart';

class DocumentRouter {
  static final FileService _fileService = FileService();

  static Future<void> routeDocument(
    BuildContext context,
    String filePath, {
    bool isExternal = false,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File not found: ${p.basename(filePath)}')),
        );
      }
      return;
    }

    String workingPath = filePath;

    if (isExternal && context.mounted) {
      final shouldImport = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Open Document', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            'Received "${p.basename(filePath)}".\n\nWould you like to import a copy into your TK Office documents or open directly?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Open Directly'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import Copy'),
            ),
          ],
        ),
      );

      if (shouldImport == true) {
        final category = FileUtils.getCategory(filePath);
        final targetDir = await LocalStorageService.instance.getCategoryDirectory(category);
        final destPath = p.join(targetDir.path, p.basename(filePath));
        await file.copy(destPath);
        workingPath = destPath;
      }
    }

    await _fileService.recordRecentFile(workingPath);
    final category = FileUtils.getCategory(workingPath);

    if (!context.mounted) return;

    switch (category) {
      case DocumentCategory.document:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => WriterScreen(filePath: workingPath)),
        );
        break;
      case DocumentCategory.spreadsheet:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SheetsScreen(filePath: workingPath)),
        );
        break;
      case DocumentCategory.presentation:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SlidesScreen(filePath: workingPath)),
        );
        break;
      case DocumentCategory.pdf:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PdfViewerScreen(filePath: workingPath)),
        );
        break;
      case DocumentCategory.other:
        final ext = p.extension(workingPath).toLowerCase();
        if (['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ImageToPdfScreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('TK Office cannot open $ext files.')),
          );
        }
        break;
    }
  }
}
