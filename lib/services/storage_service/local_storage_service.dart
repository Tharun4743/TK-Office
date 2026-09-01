import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/app_constants.dart';
import '../../utils/file_utils.dart';

class LocalStorageService {
  static final LocalStorageService instance = LocalStorageService._();
  LocalStorageService._();

  Future<Directory> getAppDocumentsDirectory() async {
    if (Platform.isAndroid) {
      try {
        final extDocs = Directory('/storage/emulated/0/Documents');
        if (await extDocs.exists()) {
          final tkSharedDir = Directory('/storage/emulated/0/Documents/${AppConstants.rootFolderName}');
          if (!await tkSharedDir.exists()) {
            await tkSharedDir.create(recursive: true);
          }
          return tkSharedDir;
        }
      } catch (_) {}
    }

    final baseDir = await getApplicationDocumentsDirectory();
    final tkDir = Directory(p.join(baseDir.path, AppConstants.rootFolderName));
    if (!await tkDir.exists()) {
      await tkDir.create(recursive: true);
    }
    return tkDir;
  }

  Future<Directory> getCategoryDirectory(DocumentCategory category) async {
    final rootDir = await getAppDocumentsDirectory();
    String subFolder;
    switch (category) {
      case DocumentCategory.document:
        subFolder = AppConstants.documentsFolder;
        break;
      case DocumentCategory.spreadsheet:
        subFolder = AppConstants.spreadsheetsFolder;
        break;
      case DocumentCategory.presentation:
        subFolder = AppConstants.presentationsFolder;
        break;
      case DocumentCategory.pdf:
        subFolder = AppConstants.pdfsFolder;
        break;
      case DocumentCategory.other:
        subFolder = 'Other';
        break;
    }

    final targetDir = Directory(p.join(rootDir.path, subFolder));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir;
  }

  Future<Directory> getRecoveryDirectory() async {
    final rootDir = await getAppDocumentsDirectory();
    final recoveryDir = Directory(p.join(rootDir.path, AppConstants.recoveryFolder));
    if (!await recoveryDir.exists()) {
      await recoveryDir.create(recursive: true);
    }
    return recoveryDir;
  }

  Future<String> generateUniqueFilePath({
    required String baseName,
    required String extension,
    required DocumentCategory category,
  }) async {
    final dir = await getCategoryDirectory(category);
    final sanitizedBase = FileUtils.sanitizeFileName(baseName);
    var candidate = p.join(dir.path, '$sanitizedBase$extension');
    var counter = 1;

    while (await File(candidate).exists()) {
      candidate = p.join(dir.path, '${sanitizedBase}_$counter$extension');
      counter++;
    }

    return candidate;
  }
}
