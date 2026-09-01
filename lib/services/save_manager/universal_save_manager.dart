import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/app_theme.dart';
import '../../features/file_manager/folder_browser_screen.dart';
import '../../models/file_info.dart';
import '../../services/conversion_service/output_validator.dart';
import '../../services/file_service/file_service.dart';
import '../../services/routing/document_router.dart';
import '../../services/storage_scanner_service/storage_scanner_service.dart';
import '../../services/storage_service/local_storage_service.dart';
import '../../storage/conversion_history_dao.dart';
import '../../storage/indexed_files_dao.dart';
import '../../utils/file_utils.dart';

class SaveLocationOption {
  final String label;
  final String path;
  final IconData icon;

  SaveLocationOption({required this.label, required this.path, required this.icon});
}

class UniversalSaveManager {
  /// Sanitize filename, strip illegal characters, and ensure clean single extension.
  static String sanitizeFileName(String input, String targetExt) {
    String clean = input.trim();
    clean = clean.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    clean = clean.replaceAll(RegExp(r'\s+'), ' ');

    final ext = targetExt.startsWith('.') ? targetExt.toLowerCase() : '.$targetExt'.toLowerCase();
    if (clean.toLowerCase().endsWith(ext)) {
      return clean;
    }
    return '$clean$ext';
  }

  /// Get accessible save locations (Download, Documents, Pictures, TK Office, etc.)
  static Future<List<SaveLocationOption>> getAvailableSaveLocations([DocumentCategory? category]) async {
    final List<SaveLocationOption> options = [];

    if (Platform.isAndroid) {
      final root = await StorageScannerService.getRootStoragePath() ?? '/storage/emulated/0';

      // 1. Download
      final downloadDir = Directory(p.join(root, 'Download'));
      if (await downloadDir.exists()) {
        options.add(SaveLocationOption(label: 'Download', path: downloadDir.path, icon: Icons.download_rounded));
      }

      // 2. Documents
      final docsDir = Directory(p.join(root, 'Documents'));
      if (await docsDir.exists()) {
        options.add(SaveLocationOption(label: 'Documents', path: docsDir.path, icon: Icons.folder_rounded));
      }

      // 3. Pictures (for images)
      final picDir = Directory(p.join(root, 'Pictures'));
      if (await picDir.exists()) {
        options.add(SaveLocationOption(label: 'Pictures', path: picDir.path, icon: Icons.photo_library_rounded));
      }

      // 4. TK Office Folder
      final tkOfficeDir = Directory(p.join(root, 'Documents', 'TK Office'));
      if (!await tkOfficeDir.exists()) {
        try {
          await tkOfficeDir.create(recursive: true);
        } catch (_) {}
      }
      if (await tkOfficeDir.exists()) {
        options.add(SaveLocationOption(label: 'TK Office', path: tkOfficeDir.path, icon: Icons.business_center_rounded));
      }
    }

    // Default App Documents directory fallback
    try {
      final appDocs = await LocalStorageService.instance.getAppDocumentsDirectory();
      if (!options.any((o) => o.path == appDocs.path)) {
        options.add(SaveLocationOption(label: 'TK Office (App Storage)', path: appDocs.path, icon: Icons.storage_rounded));
      }
    } catch (_) {}

    return options;
  }

  /// Universal workflow for saving a single converted/exported temporary file.
  static Future<String?> saveConvertedFile({
    required BuildContext context,
    required String defaultFileName,
    required String targetExtension,
    required DocumentCategory category,
    required File tempOutputFile,
    String? conversionType,
    String? sourceFileName,
    bool showSuccessDialog = true,
  }) async {
    final ext = targetExtension.startsWith('.') ? targetExtension : '.$targetExtension';

    // 1. Strict Output Validation before prompting
    final validation = await OutputValidator.validateFile(tempOutputFile, ext);
    if (!validation.isValid) {
      if (await tempOutputFile.exists()) {
        try {
          await tempOutputFile.delete();
        } catch (_) {}
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversion Validation Failed: ${validation.errorMessage ?? "Invalid output"}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }

    final baseName = p.basenameWithoutExtension(defaultFileName);
    final availableLocations = await getAvailableSaveLocations(category);

    // Initial default directory (Download or Documents or first available)
    String selectedDirPath = availableLocations.isNotEmpty ? availableLocations.first.path : (await getTemporaryDirectory()).path;

    final saveResult = await _promptLiveSaveDialog(
      context: context,
      title: 'Save Converted File',
      initialName: baseName,
      extension: ext,
      availableLocations: availableLocations,
      initialSelectedDirPath: selectedDirPath,
    );

    if (saveResult == null) {
      // User cancelled
      if (await tempOutputFile.exists()) {
        try {
          await tempOutputFile.delete();
        } catch (_) {}
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save cancelled.')),
        );
      }
      return null;
    }

    final finalFileName = sanitizeFileName(saveResult.fileName, ext);
    String destPath = p.join(saveResult.directoryPath, finalFileName);
    final targetFile = File(destPath);

    // Overwrite Collision Detection
    if (await targetFile.exists() && context.mounted) {
      final action = await _promptCollisionDialog(context, finalFileName, p.basename(saveResult.directoryPath));
      if (action == 'cancel' || action == null) {
        if (await tempOutputFile.exists()) await tempOutputFile.delete();
        return null;
      } else if (action == 'new_name') {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        destPath = p.join(saveResult.directoryPath, '${p.basenameWithoutExtension(finalFileName)}_$timestamp$ext');
      }
    }

    // Move/Copy temporary file to user-selected final destination
    try {
      final targetDestFile = File(destPath);
      final parentDir = targetDestFile.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }
      await tempOutputFile.copy(destPath);
      if (await tempOutputFile.exists()) {
        try {
          await tempOutputFile.delete();
        } catch (_) {}
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving to destination: $e'), backgroundColor: Colors.red),
        );
      }
      return null;
    }

    // Verify output file exists and has valid content
    final savedFile = File(destPath);
    final finalVal = await OutputValidator.validateFile(savedFile, ext);
    if (!finalVal.isValid) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${finalVal.errorMessage}'), backgroundColor: Colors.red),
        );
      }
      return null;
    }

    // Record to Recents & SQLite Index with the REAL path selected by user
    final stat = savedFile.statSync();
    await FileService().recordRecentFile(destPath);
    await IndexedFilesDao().batchInsertOrUpdate([
      LocalFileInfo(
        path: destPath,
        name: p.basename(destPath),
        extension: ext,
        sizeInBytes: stat.size,
        modifiedDate: stat.modified,
        category: category,
        folderName: p.basename(saveResult.directoryPath),
      ),
    ]);

    // Record to Conversion History
    if (conversionType != null) {
      await ConversionHistoryDao().recordConversion(
        ConversionHistoryItem(
          sourceName: sourceFileName ?? 'Document',
          targetName: p.basename(destPath),
          targetPath: destPath,
          conversionType: conversionType,
          timestamp: DateTime.now(),
          isSuccess: true,
          fileSize: stat.size,
        ),
      );
    }

    if (showSuccessDialog && context.mounted) {
      showSaveSuccessDialog(context: context, filePath: destPath);
    }

    return destPath;
  }

  /// Universal workflow for saving multiple converted temporary files (e.g. PDF -> Images, PDF Split).
  static Future<List<String>?> saveMultipleConvertedFiles({
    required BuildContext context,
    required List<String> tempFilePaths,
    required String defaultBaseName,
    required String targetExtension,
    required DocumentCategory category,
    String? conversionType,
    String? sourceFileName,
  }) async {
    if (tempFilePaths.isEmpty) return null;

    final ext = targetExtension.startsWith('.') ? targetExtension : '.$targetExtension';
    final availableLocations = await getAvailableSaveLocations(category);

    String selectedDirPath = availableLocations.isNotEmpty ? availableLocations.first.path : (await getTemporaryDirectory()).path;

    final saveResult = await _promptMultiFileSaveDialog(
      context: context,
      title: 'Save Converted Files',
      totalFilesCount: tempFilePaths.length,
      initialBaseName: defaultBaseName,
      extension: ext,
      availableLocations: availableLocations,
      initialSelectedDirPath: selectedDirPath,
    );

    if (saveResult == null) {
      // User cancelled: clean up all temp files
      for (final p in tempFilePaths) {
        try {
          final f = File(p);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save cancelled.')),
        );
      }
      return null;
    }

    final destDir = Directory(saveResult.directoryPath);
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    final List<String> savedPaths = [];
    final List<LocalFileInfo> indexedList = [];

    for (int i = 0; i < tempFilePaths.length; i++) {
      final tempFile = File(tempFilePaths[i]);
      final pageIndexStr = (i + 1).toString().padLeft(3, '0');
      final fileName = '${saveResult.baseName}_page_$pageIndexStr$ext';
      final destPath = p.join(destDir.path, fileName);

      try {
        await tempFile.copy(destPath);
        if (await tempFile.exists()) {
          try {
            await tempFile.delete();
          } catch (_) {}
        }

        final finalSaved = File(destPath);
        if (await finalSaved.exists() && finalSaved.lengthSync() > 0) {
          savedPaths.add(destPath);
          final stat = finalSaved.statSync();
          indexedList.add(
            LocalFileInfo(
              path: destPath,
              name: fileName,
              extension: ext,
              sizeInBytes: stat.size,
              modifiedDate: stat.modified,
              category: category,
              folderName: p.basename(destDir.path),
            ),
          );
        }
      } catch (_) {}
    }

    if (savedPaths.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving files to selected destination.'), backgroundColor: Colors.red),
        );
      }
      return null;
    }

    // Record all files to Recents & SQLite Index with REAL destination paths
    for (final path in savedPaths) {
      await FileService().recordRecentFile(path);
    }
    await IndexedFilesDao().batchInsertOrUpdate(indexedList);

    // Record to Conversion History
    if (conversionType != null) {
      await ConversionHistoryDao().recordConversion(
        ConversionHistoryItem(
          sourceName: sourceFileName ?? 'Document',
          targetName: '${p.basename(savedPaths.first)} (+${savedPaths.length - 1} files)',
          targetPath: savedPaths.first,
          conversionType: conversionType,
          timestamp: DateTime.now(),
          isSuccess: true,
          fileSize: File(savedPaths.first).lengthSync(),
        ),
      );
    }

    if (context.mounted) {
      showMultiSaveSuccessDialog(
        context: context,
        savedFolder: destDir.path,
        savedFiles: savedPaths,
      );
    }

    return savedPaths;
  }

  /// Live Single-File Save Dialog with editable Filename AND Folder Selector
  static Future<_SingleSaveResult?> _promptLiveSaveDialog({
    required BuildContext context,
    required String title,
    required String initialName,
    required String extension,
    required List<SaveLocationOption> availableLocations,
    required String initialSelectedDirPath,
  }) async {
    final nameController = TextEditingController(text: initialName);
    final formKey = GlobalKey<FormState>();
    String currentDirPath = initialSelectedDirPath;

    return showDialog<_SingleSaveResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentFolderLabel = p.basename(currentDirPath);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.save_as_rounded, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Enter filename and choose save destination:', style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 14),

                    // File Name Input
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'File Name',
                        suffixText: extension,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter a filename';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Destination Location Picker
                    const Text('Save Destination:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_open_rounded, color: AppTheme.primaryBlue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(currentFolderLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(currentDirPath, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.swap_horiz_rounded, color: AppTheme.primaryBlue),
                            tooltip: 'Change Destination Folder',
                            onSelected: (selected) async {
                              if (selected == '__browse_custom__') {
                                final root = await StorageScannerService.getRootStoragePath() ?? '/storage/emulated/0';
                                if (context.mounted) {
                                  final chosen = await Navigator.push<String>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FolderBrowserScreen(initialPath: root, folderTitle: 'Select Folder'),
                                    ),
                                  );
                                  if (chosen != null) {
                                    setModalState(() => currentDirPath = chosen);
                                  }
                                }
                              } else {
                                setModalState(() => currentDirPath = selected);
                              }
                            },
                            itemBuilder: (_) => [
                              ...availableLocations.map(
                                (loc) => PopupMenuItem(
                                  value: loc.path,
                                  child: Row(
                                    children: [
                                      Icon(loc.icon, size: 18, color: AppTheme.primaryBlue),
                                      const SizedBox(width: 8),
                                      Text(loc.label),
                                    ],
                                  ),
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: '__browse_custom__',
                                child: Row(
                                  children: [
                                    Icon(Icons.folder_special_rounded, size: 18, color: Colors.teal),
                                    SizedBox(width: 8),
                                    Text('Browse Any Folder...'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() == true) {
                      Navigator.pop(
                        ctx,
                        _SingleSaveResult(
                          fileName: nameController.text.trim(),
                          directoryPath: currentDirPath,
                        ),
                      );
                    }
                  },
                  child: const Text('Save File'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Live Multi-File Save Dialog (for PDF -> Images, PDF Split)
  static Future<_MultiSaveResult?> _promptMultiFileSaveDialog({
    required BuildContext context,
    required String title,
    required int totalFilesCount,
    required String initialBaseName,
    required String extension,
    required List<SaveLocationOption> availableLocations,
    required String initialSelectedDirPath,
  }) async {
    final nameController = TextEditingController(text: initialBaseName);
    final formKey = GlobalKey<FormState>();
    String currentDirPath = initialSelectedDirPath;

    return showDialog<_MultiSaveResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentFolderLabel = p.basename(currentDirPath);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.photo_library_rounded, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Generated $totalFilesCount output files ($extension)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Base Name Input
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Base File Name',
                        helperText: 'Files will be saved as ${nameController.text}_page_001$extension',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Please enter a base filename';
                        return null;
                      },
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Destination Folder
                    const Text('Save Destination Folder:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_open_rounded, color: AppTheme.primaryBlue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(currentFolderLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(currentDirPath, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.swap_horiz_rounded, color: AppTheme.primaryBlue),
                            tooltip: 'Change Destination Folder',
                            onSelected: (selected) async {
                              if (selected == '__browse_custom__') {
                                final root = await StorageScannerService.getRootStoragePath() ?? '/storage/emulated/0';
                                if (context.mounted) {
                                  final chosen = await Navigator.push<String>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FolderBrowserScreen(initialPath: root, folderTitle: 'Select Folder'),
                                    ),
                                  );
                                  if (chosen != null) {
                                    setModalState(() => currentDirPath = chosen);
                                  }
                                }
                              } else {
                                setModalState(() => currentDirPath = selected);
                              }
                            },
                            itemBuilder: (_) => [
                              ...availableLocations.map(
                                (loc) => PopupMenuItem(
                                  value: loc.path,
                                  child: Row(
                                    children: [
                                      Icon(loc.icon, size: 18, color: AppTheme.primaryBlue),
                                      const SizedBox(width: 8),
                                      Text(loc.label),
                                    ],
                                  ),
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: '__browse_custom__',
                                child: Row(
                                  children: [
                                    Icon(Icons.folder_special_rounded, size: 18, color: Colors.teal),
                                    SizedBox(width: 8),
                                    Text('Browse Any Folder...'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() == true) {
                      Navigator.pop(
                        ctx,
                        _MultiSaveResult(
                          baseName: nameController.text.trim(),
                          directoryPath: currentDirPath,
                        ),
                      );
                    }
                  },
                  child: Text('Save $totalFilesCount Files'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Future<String?> _promptCollisionDialog(BuildContext context, String fileName, String folderName) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('File Already Exists', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('A file named "$fileName" already exists in $folderName. What would you like to do?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, 'new_name'),
            child: const Text('Save as New Name'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'replace'),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
  }

  static Future<void> showSaveSuccessDialog({
    required BuildContext context,
    required String filePath,
  }) async {
    final file = File(filePath);
    final fileName = p.basename(filePath);
    final stat = file.existsSync() ? file.statSync() : null;
    final cat = FileUtils.getCategory(filePath);
    final color = FileUtils.getCategoryColor(cat);
    final icon = FileUtils.getCategoryIcon(cat);

    return showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
              const SizedBox(height: 12),
              const Text('File Saved Successfully!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(fileName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.center),
              if (stat != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${FileUtils.formatFileSize(stat.size)} • ${p.dirname(filePath)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label: const Text('Share'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        FileService().shareFile(filePath);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      icon: Icon(icon, size: 16),
                      label: const Text('Open'),
                      style: FilledButton.styleFrom(backgroundColor: color),
                      onPressed: () {
                        Navigator.pop(ctx);
                        DocumentRouter.routeDocument(context, filePath);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> showMultiSaveSuccessDialog({
    required BuildContext context,
    required String savedFolder,
    required List<String> savedFiles,
  }) async {
    return showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
              const SizedBox(height: 12),
              Text('Saved ${savedFiles.length} Files!', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Destination:\n$savedFolder',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label: const Text('Share First'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (savedFiles.isNotEmpty) {
                          FileService().shareFile(savedFiles.first);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.folder_open_rounded, size: 16),
                      label: const Text('View Folder'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FolderBrowserScreen(
                              initialPath: savedFolder,
                              folderTitle: p.basename(savedFolder),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SingleSaveResult {
  final String fileName;
  final String directoryPath;

  _SingleSaveResult({required this.fileName, required this.directoryPath});
}

class _MultiSaveResult {
  final String baseName;
  final String directoryPath;

  _MultiSaveResult({required this.baseName, required this.directoryPath});
}
