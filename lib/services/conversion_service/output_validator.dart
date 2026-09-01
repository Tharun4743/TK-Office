import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as xl;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

class OutputValidationResult {
  final bool isValid;
  final String? errorMessage;
  final int fileSize;
  final String fileExtension;

  OutputValidationResult({
    required this.isValid,
    this.errorMessage,
    required this.fileSize,
    required this.fileExtension,
  });
}

class OutputValidator {
  /// Polymorphic file validator based on target extension
  static Future<OutputValidationResult> validateFile(File file, [String? expectedExtension]) async {
    if (!await file.exists()) {
      return OutputValidationResult(
        isValid: false,
        errorMessage: 'Output file was not found on disk.',
        fileSize: 0,
        fileExtension: '',
      );
    }

    final size = file.lengthSync();
    if (size == 0) {
      return OutputValidationResult(
        isValid: false,
        errorMessage: 'Output file is empty (0 bytes).',
        fileSize: 0,
        fileExtension: '',
      );
    }

    final ext = (expectedExtension ?? p.extension(file.path)).toLowerCase();

    try {
      switch (ext) {
        case '.pdf':
          final ok = await validatePdf(file);
          return OutputValidationResult(
            isValid: ok,
            errorMessage: ok ? null : 'Generated PDF has an invalid structure or could not be reopened.',
            fileSize: size,
            fileExtension: ext,
          );

        case '.docx':
          final ok = await validateDocx(file);
          return OutputValidationResult(
            isValid: ok,
            errorMessage: ok ? null : 'Generated DOCX is not a valid OpenXML package.',
            fileSize: size,
            fileExtension: ext,
          );

        case '.xlsx':
          final ok = await validateXlsx(file);
          return OutputValidationResult(
            isValid: ok,
            errorMessage: ok ? null : 'Generated XLSX is not a valid spreadsheet workbook.',
            fileSize: size,
            fileExtension: ext,
          );

        case '.pptx':
          final ok = await validatePptx(file);
          return OutputValidationResult(
            isValid: ok,
            errorMessage: ok ? null : 'Generated PPTX is not a valid presentation package.',
            fileSize: size,
            fileExtension: ext,
          );

        case '.jpg':
        case '.jpeg':
        case '.png':
        case '.webp':
          final ok = await validateImage(file);
          return OutputValidationResult(
            isValid: ok,
            errorMessage: ok ? null : 'Generated image is corrupted or cannot be decoded.',
            fileSize: size,
            fileExtension: ext,
          );

        case '.txt':
        case '.csv':
          final ok = await validateText(file);
          return OutputValidationResult(
            isValid: ok,
            errorMessage: ok ? null : 'Generated text file is empty or unreadable.',
            fileSize: size,
            fileExtension: ext,
          );

        default:
          return OutputValidationResult(
            isValid: size > 0,
            fileSize: size,
            fileExtension: ext,
          );
      }
    } catch (e) {
      return OutputValidationResult(
        isValid: false,
        errorMessage: 'Validation failed: $e',
        fileSize: size,
        fileExtension: ext,
      );
    }
  }

  static Future<bool> validatePdf(File file) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length < 10) return false;
      final header = String.fromCharCodes(bytes.take(4));
      if (!header.startsWith('%PDF')) return false;

      final sfDoc = sf.PdfDocument(inputBytes: bytes);
      final count = sfDoc.pages.count;
      sfDoc.dispose();
      return count > 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> validateDocx(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      return archive.files.any((f) => f.name == 'word/document.xml');
    } catch (_) {
      return false;
    }
  }

  static Future<bool> validateXlsx(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final excel = xl.Excel.decodeBytes(bytes);
      return excel.tables.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> validatePptx(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      return archive.files.any((f) => f.name.startsWith('ppt/slides/slide'));
    } catch (_) {
      return false;
    }
  }

  static Future<bool> validateImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      return decoded != null && decoded.width > 0 && decoded.height > 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> validateText(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final str = utf8.decode(bytes, allowMalformed: true);
      return str.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
