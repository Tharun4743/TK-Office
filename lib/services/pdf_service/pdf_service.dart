import 'dart:convert';
import 'dart:io';
import 'package:printing/printing.dart';
import '../../models/pdf_annotation_model.dart';

class PdfService {
  static Future<List<PdfAnnotation>> loadAnnotations(String pdfPath) async {
    final sidecarPath = '$pdfPath.annotations.json';
    final file = File(sidecarPath);
    if (!await file.exists()) return [];

    try {
      final jsonString = await file.readAsString();
      final List<dynamic> list = jsonDecode(jsonString) as List<dynamic>;
      return list.map((e) => PdfAnnotation.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAnnotations(String pdfPath, List<PdfAnnotation> annotations) async {
    final sidecarPath = '$pdfPath.annotations.json';
    final file = File(sidecarPath);
    final list = annotations.map((e) => e.toMap()).toList();
    await file.writeAsString(jsonEncode(list));
  }

  static Future<void> printPdf(String pdfPath, {String? title}) async {
    final file = File(pdfPath);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: title ?? file.uri.pathSegments.last,
      );
    }
  }
}
