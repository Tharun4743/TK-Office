import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/file_info.dart';
import '../../services/save_manager/universal_save_manager.dart';
import '../../utils/file_utils.dart';

class SaveFileDialog {
  static String sanitizeFileName(String input, String targetExt) {
    return UniversalSaveManager.sanitizeFileName(input, targetExt);
  }

  static Future<String?> show({
    required BuildContext context,
    required String defaultFileName,
    required String targetExtension,
    required DocumentCategory category,
    required File tempOutputFile,
    String? conversionType,
    String? sourceFileName,
  }) {
    return UniversalSaveManager.saveConvertedFile(
      context: context,
      defaultFileName: defaultFileName,
      targetExtension: targetExtension,
      category: category,
      tempOutputFile: tempOutputFile,
      conversionType: conversionType,
      sourceFileName: sourceFileName,
      showSuccessDialog: false, // Dialog handled by caller or UniversalSaveManager
    );
  }
}

class SaveSuccessDialog {
  static Future<void> show({
    required BuildContext context,
    required String filePath,
  }) {
    return UniversalSaveManager.showSaveSuccessDialog(
      context: context,
      filePath: filePath,
    );
  }
}
