import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import '../../models/file_info.dart';
import '../../models/recent_file.dart';
import '../../storage/recent_files_dao.dart';
import '../../utils/file_utils.dart';
import '../storage_service/local_storage_service.dart';

class FileService {
  final RecentFilesDao _recentFilesDao = RecentFilesDao();
  static const MethodChannel _shareChannel = MethodChannel('com.tk.tk_office/share');

  Future<String?> pickFileFromDevice({List<String>? allowedExtensions}) async {
    final result = await FilePicker.pickFiles(
      type: allowedExtensions != null && allowedExtensions.isNotEmpty
          ? FileType.custom
          : FileType.any,
      allowedExtensions: allowedExtensions,
    );

    if (result.isNotEmpty && result.first.path != null) {
      final path = result.first.path!;
      await recordRecentFile(path);
      return path;
    }
    return null;
  }

  Future<void> recordRecentFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      final length = await file.length();
      final title = p.basename(filePath);
      final category = FileUtils.getCategory(filePath);

      await _recentFilesDao.insertOrUpdate(
        RecentFile(
          path: filePath,
          title: title,
          category: category,
          sizeInBytes: length,
          lastOpened: DateTime.now(),
        ),
      );
    }
  }

  Future<List<LocalFileInfo>> listFilesInCategory(DocumentCategory category) async {
    final dir = await LocalStorageService.instance.getCategoryDirectory(category);
    return _listFilesInDirectory(dir);
  }

  Future<List<LocalFileInfo>> listAllLocalFiles() async {
    final rootDir = await LocalStorageService.instance.getAppDocumentsDirectory();
    final List<LocalFileInfo> allFiles = [];

    if (await rootDir.exists()) {
      final entities = rootDir.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is File) {
          final stat = entity.statSync();
          final category = FileUtils.getCategory(entity.path);
          allFiles.add(
            LocalFileInfo(
              path: entity.path,
              name: p.basename(entity.path),
              extension: p.extension(entity.path),
              sizeInBytes: stat.size,
              modifiedDate: stat.modified,
              category: category,
              isDirectory: false,
            ),
          );
        }
      }
    }

    allFiles.sort((a, b) => b.modifiedDate.compareTo(a.modifiedDate));
    return allFiles;
  }

  List<LocalFileInfo> _listFilesInDirectory(Directory dir) {
    if (!dir.existsSync()) return [];
    final List<LocalFileInfo> files = [];

    for (final entity in dir.listSync()) {
      if (entity is File) {
        final stat = entity.statSync();
        final category = FileUtils.getCategory(entity.path);
        files.add(
          LocalFileInfo(
            path: entity.path,
            name: p.basename(entity.path),
            extension: p.extension(entity.path),
            sizeInBytes: stat.size,
            modifiedDate: stat.modified,
            category: category,
            isDirectory: false,
          ),
        );
      }
    }

    files.sort((a, b) => b.modifiedDate.compareTo(a.modifiedDate));
    return files;
  }

  Future<bool> renameFile(String currentPath, String newNameWithoutExt) async {
    try {
      final file = File(currentPath);
      if (!await file.exists()) return false;

      final dir = p.dirname(currentPath);
      final ext = p.extension(currentPath);
      final sanitized = FileUtils.sanitizeFileName(newNameWithoutExt);
      final newPath = p.join(dir, '$sanitized$ext');

      if (await File(newPath).exists() && newPath != currentPath) {
        return false; // Target already exists
      }

      await file.rename(newPath);
      await _recentFilesDao.delete(currentPath);
      await recordRecentFile(newPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      await _recentFilesDao.delete(filePath);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> duplicateFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final dir = p.dirname(filePath);
      final baseName = p.basenameWithoutExtension(filePath);
      final ext = p.extension(filePath);

      var newPath = p.join(dir, '${baseName}_copy$ext');
      var counter = 1;
      while (await File(newPath).exists()) {
        newPath = p.join(dir, '${baseName}_copy_$counter$ext');
        counter++;
      }

      await file.copy(newPath);
      await recordRecentFile(newPath);
      return newPath;
    } catch (_) {
      return null;
    }
  }

  Future<void> shareFile(String filePath) async {
    try {
      await _shareChannel.invokeMethod('shareFile', {
        'filePath': filePath,
        'title': 'Share ${p.basename(filePath)}',
      });
    } catch (_) {
      // Fallback
    }
  }

  Future<void> openExternally(String filePath) async {
    await OpenFile.open(filePath);
  }
}
