import 'dart:io';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/document_model.dart';
import '../../utils/file_utils.dart';
import '../storage_service/local_storage_service.dart';
import 'docx_service.dart';
import 'rtf_txt_service.dart';

class DocumentService {
  Future<OfficeDocument> createNewDocument({String title = 'Untitled Document'}) async {
    final path = await LocalStorageService.instance.generateUniqueFilePath(
      baseName: title,
      extension: '.docx',
      category: DocumentCategory.document,
    );

    final doc = OfficeDocument(
      filePath: path,
      title: title,
      delta: Delta()..insert('\n'),
      lastModified: DateTime.now(),
    );

    await saveDocument(doc);
    return doc;
  }

  Future<OfficeDocument> loadDocument(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }

    final ext = p.extension(filePath).toLowerCase();
    final title = p.basenameWithoutExtension(filePath);
    Delta delta;

    if (ext == '.docx') {
      delta = await DocxService.importDocx(filePath);
    } else if (ext == '.doc') {
      delta = await DocxService.importDocx(filePath);
      final ops = delta.toList();
      if (ops.isNotEmpty && ops.first.data is String && (ops.first.data as String).startsWith('Error reading DOCX file')) {
        delta = Delta()..insert('This appears to be a legacy binary .doc file which is not supported offline. Please open a .docx file or convert it first.\n');
      }
    } else if (ext == '.txt') {
      delta = await RtfTxtService.importTxt(filePath);
    } else if (ext == '.json') {
      final content = await file.readAsString();
      return OfficeDocument.fromJsonString(content, filePath: filePath, title: title);
    } else {
      delta = await RtfTxtService.importTxt(filePath);
    }

    return OfficeDocument(
      filePath: filePath,
      title: title,
      delta: delta,
      lastModified: file.statSync().modified,
      isDirty: false,
    );
  }

  Future<void> saveDocument(OfficeDocument doc) async {
    doc.filePath ??= await LocalStorageService.instance.generateUniqueFilePath(
      baseName: doc.title,
      extension: '.docx',
      category: DocumentCategory.document,
    );

    final file = File(doc.filePath!);
    final ext = p.extension(doc.filePath!).toLowerCase();

    if (ext == '.docx') {
      final bytes = DocxService.exportToDocx(doc.delta);
      await file.writeAsBytes(bytes);
    } else if (ext == '.txt') {
      final text = RtfTxtService.exportToPlainText(doc.delta);
      await file.writeAsString(text);
    } else if (ext == '.rtf') {
      final rtf = RtfTxtService.exportToRtf(doc.delta);
      await file.writeAsString(rtf);
    } else if (ext == '.json') {
      await file.writeAsString(doc.toJsonString());
    } else {
      final bytes = DocxService.exportToDocx(doc.delta);
      await file.writeAsBytes(bytes);
    }

    doc.isDirty = false;
    doc.lastModified = DateTime.now();
  }

  Future<String> exportToPdf(OfficeDocument doc) async {
    final pdfDoc = pw.Document();
    final operations = doc.delta.toList();

    final List<pw.Widget> contentWidgets = [];
    var currentSpans = <pw.InlineSpan>[];
    pw.TextAlign currentAlign = pw.TextAlign.left;

    void flushParagraph() {
      if (currentSpans.isNotEmpty) {
        contentWidgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.RichText(
              textAlign: currentAlign,
              text: pw.TextSpan(children: List.from(currentSpans)),
            ),
          ),
        );
        currentSpans = [];
        currentAlign = pw.TextAlign.left;
      }
    }

    for (final op in operations) {
      final data = op.data;
      if (data is String) {
        final lines = data.split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.isNotEmpty) {
            final attrs = op.attributes ?? {};
            final isBold = attrs['bold'] == true;
            final isItalic = attrs['italic'] == true;
            final isUnderline = attrs['underline'] == true;

            currentSpans.add(
              pw.TextSpan(
                text: line,
                style: pw.TextStyle(
                  fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  fontStyle: isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
                  decoration: isUnderline ? pw.TextDecoration.underline : pw.TextDecoration.none,
                  fontSize: 12,
                ),
              ),
            );
          }

          if (i < lines.length - 1) {
            final blockAttrs = op.attributes;
            if (blockAttrs != null && blockAttrs.containsKey('align')) {
              final align = blockAttrs['align'];
              if (align == 'center') currentAlign = pw.TextAlign.center;
              if (align == 'right') currentAlign = pw.TextAlign.right;
              if (align == 'justify') currentAlign = pw.TextAlign.justify;
            }
            flushParagraph();
          }
        }
      }
    }
    flushParagraph();

    pdfDoc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => contentWidgets,
      ),
    );

    final pdfBytes = await pdfDoc.save();
    final pdfPath = await LocalStorageService.instance.generateUniqueFilePath(
      baseName: doc.title,
      extension: '.pdf',
      category: DocumentCategory.pdf,
    );

    final pdfFile = File(pdfPath);
    await pdfFile.writeAsBytes(pdfBytes);
    return pdfPath;
  }

  Future<void> printDocument(OfficeDocument doc) async {
    final pdfPath = await exportToPdf(doc);
    final file = File(pdfPath);
    final bytes = await file.readAsBytes();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: doc.title,
    );
  }
}
