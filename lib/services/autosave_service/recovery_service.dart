import 'dart:io';
import 'package:path/path.dart' as p;
import '../../models/file_info.dart';
import '../../utils/file_utils.dart';
import '../storage_service/local_storage_service.dart';

class RecoveryService {
  static Future<List<LocalFileInfo>> checkRecoveredDocuments() async {
    final recoveryDir = await LocalStorageService.instance.getRecoveryDirectory();
    if (!await recoveryDir.exists()) return [];

    final List<LocalFileInfo> recovered = [];
    for (final entity in recoveryDir.listSync()) {
      if (entity is File) {
        final stat = entity.statSync();
        final category = FileUtils.getCategory(entity.path);
        recovered.add(
          LocalFileInfo(
            path: entity.path,
            name: p.basename(entity.path),
            extension: p.extension(entity.path),
            sizeInBytes: stat.size,
            modifiedDate: stat.modified,
            category: category,
          ),
        );
      }
    }
    return recovered;
  }

  static Future<void> saveEmergencyRecoveryCopy({
    required String baseName,
    required String extension,
    required List<int> bytes,
  }) async {
    final recoveryDir = await LocalStorageService.instance.getRecoveryDirectory();
    final sanitized = FileUtils.sanitizeFileName(baseName);
    final recoveryFile = File(p.join(recoveryDir.path, '${sanitized}_recovery$extension'));
    await recoveryFile.writeAsBytes(bytes);
  }
}
