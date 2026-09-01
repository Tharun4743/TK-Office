import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../core/app_theme.dart';

enum DocumentCategory {
  document,
  spreadsheet,
  presentation,
  pdf,
  other,
}

class FileUtils {
  static DocumentCategory getCategory(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    switch (ext) {
      case '.docx':
      case '.doc':
      case '.odt':
      case '.txt':
      case '.rtf':
        return DocumentCategory.document;
      case '.xlsx':
      case '.xls':
      case '.ods':
      case '.csv':
        return DocumentCategory.spreadsheet;
      case '.pptx':
      case '.ppt':
      case '.odp':
        return DocumentCategory.presentation;
      case '.pdf':
        return DocumentCategory.pdf;
      default:
        return DocumentCategory.other;
    }
  }

  static Color getCategoryColor(DocumentCategory category) {
    switch (category) {
      case DocumentCategory.document:
        return AppTheme.docBlue;
      case DocumentCategory.spreadsheet:
        return AppTheme.sheetGreen;
      case DocumentCategory.presentation:
        return AppTheme.slideOrange;
      case DocumentCategory.pdf:
        return AppTheme.pdfRed;
      case DocumentCategory.other:
        return Colors.blueGrey;
    }
  }

  static IconData getCategoryIcon(DocumentCategory category) {
    switch (category) {
      case DocumentCategory.document:
        return Icons.description_rounded;
      case DocumentCategory.spreadsheet:
        return Icons.table_chart_rounded;
      case DocumentCategory.presentation:
        return Icons.slideshow_rounded;
      case DocumentCategory.pdf:
        return Icons.picture_as_pdf_rounded;
      case DocumentCategory.other:
        return Icons.insert_drive_file_rounded;
    }
  }

  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(size < 10 ? 1 : 0)} ${suffixes[i]}';
  }

  static String getFileNameWithoutExtension(String filePath) {
    return p.basenameWithoutExtension(filePath);
  }

  static String sanitizeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }

  static Future<bool> fileExists(String path) async {
    return File(path).exists();
  }
}
