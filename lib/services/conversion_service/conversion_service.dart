import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../pdf_service/pdf_tools_service.dart';
import 'converters/docx_to_pdf_converter.dart';
import 'converters/pdf_to_docx_converter.dart';
import 'converters/pdf_to_xlsx_converter.dart';
import 'converters/pptx_to_pdf_converter.dart';
import 'converters/xlsx_to_pdf_converter.dart';

class ConversionService {
  static Future<File> getTempOutputFile(String prefix, String extension) async {
    final tempDir = await getTemporaryDirectory();
    final ext = extension.startsWith('.') ? extension : '.$extension';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = p.join(tempDir.path, '${prefix}_$timestamp$ext');
    return File(path);
  }

  static void validateOutputFile(File file, String expectedFormat) {
    if (!file.existsSync() || file.lengthSync() == 0) {
      throw Exception('Output validation failed: $expectedFormat file is empty or missing.');
    }
  }

  // 1. DOCX -> PDF
  static Future<File> convertDocxToPdf({
    required String inputPath,
    Function(String stage)? onProgress,
  }) async {
    final tempOut = await getTempOutputFile('converted', '.pdf');
    await DocxToPdfConverter.convert(
      inputDocxPath: inputPath,
      outputPdfPath: tempOut.path,
      onProgress: onProgress,
    );
    validateOutputFile(tempOut, 'PDF');
    return tempOut;
  }

  // 2. XLSX -> PDF
  static Future<File> convertXlsxToPdf({
    required String inputPath,
    Function(String stage)? onProgress,
  }) async {
    final tempOut = await getTempOutputFile('converted', '.pdf');
    await XlsxToPdfConverter.convert(
      inputXlsxPath: inputPath,
      outputPdfPath: tempOut.path,
      onProgress: onProgress,
    );
    validateOutputFile(tempOut, 'PDF');
    return tempOut;
  }

  // 3. PPTX -> PDF
  static Future<File> convertPptxToPdf({
    required String inputPath,
    Function(String stage)? onProgress,
  }) async {
    final tempOut = await getTempOutputFile('converted', '.pdf');
    await PptxToPdfConverter.convert(
      inputPptxPath: inputPath,
      outputPdfPath: tempOut.path,
      onProgress: onProgress,
    );
    validateOutputFile(tempOut, 'PDF');
    return tempOut;
  }

  // 4. PDF -> DOCX
  static Future<File> convertPdfToDocx({
    required String inputPath,
    Function(String stage)? onProgress,
  }) async {
    final tempOut = await getTempOutputFile('converted', '.docx');
    await PdfToDocxConverter.convert(
      inputPdfPath: inputPath,
      outputDocxPath: tempOut.path,
      onProgress: onProgress,
    );
    validateOutputFile(tempOut, 'DOCX');
    return tempOut;
  }

  // 5. PDF -> XLSX
  static Future<File> convertPdfToXlsx({
    required String inputPath,
    Function(String stage)? onProgress,
  }) async {
    final tempOut = await getTempOutputFile('converted', '.xlsx');
    await PdfToXlsxConverter.convert(
      inputPdfPath: inputPath,
      outputXlsxPath: tempOut.path,
      onProgress: onProgress,
    );
    validateOutputFile(tempOut, 'XLSX');
    return tempOut;
  }

  // 6. PDF -> TXT
  static Future<File> convertPdfToText({
    required String inputPath,
    Function(String stage)? onProgress,
  }) async {
    onProgress?.call('Extracting text content from PDF...');
    final text = await PdfToolsService.extractTextFromPdf(inputPath);
    if (text.trim().isEmpty) {
      throw Exception('Could not extract text: Document might be scanned or protected.');
    }
    final tempOut = await getTempOutputFile('extracted', '.txt');
    await tempOut.writeAsString(text);
    validateOutputFile(tempOut, 'TXT');
    return tempOut;
  }

  static Future<Directory> getTempOutputDir(String prefix) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final dir = Directory(p.join(tempDir.path, 'conversions', '${prefix}_$timestamp'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // 7. PDF -> Images
  static Future<List<String>> convertPdfToImages({
    required String inputPath,
    String? outputDir,
    String format = 'png',
    Function(String stage)? onProgress,
  }) async {
    onProgress?.call('Rendering PDF pages to images...');
    final targetDir = outputDir != null ? Directory(outputDir) : await getTempOutputDir('pdf_images');
    final images = await PdfToolsService.convertPdfToImages(
      inputPath: inputPath,
      outputDir: targetDir.path,
      format: format,
    );
    if (images.isEmpty) {
      throw Exception('Failed to render PDF pages.');
    }
    return images;
  }

  // 8. Compress PDF
  static Future<File> compressPdf({
    required String inputPath,
    int quality = 60,
    Function(String stage)? onProgress,
  }) async {
    onProgress?.call('Compressing PDF streams and embedded assets...');
    final tempOut = await getTempOutputFile('compressed', '.pdf');
    await PdfToolsService.compressPdf(
      inputPath: inputPath,
      outputPath: tempOut.path,
      imageQuality: quality,
    );
    validateOutputFile(tempOut, 'PDF');
    return tempOut;
  }

  // 9. Protect PDF
  static Future<File> protectPdf({
    required String inputPath,
    required String userPassword,
    Function(String stage)? onProgress,
  }) async {
    onProgress?.call('Encrypting PDF with 256-bit AES...');
    final tempOut = await getTempOutputFile('protected', '.pdf');
    await PdfToolsService.protectPdf(
      inputPath: inputPath,
      outputPath: tempOut.path,
      userPassword: userPassword,
    );
    validateOutputFile(tempOut, 'PDF');
    return tempOut;
  }
}
