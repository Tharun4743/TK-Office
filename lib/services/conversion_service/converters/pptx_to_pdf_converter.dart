import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';

class PptxToPdfConverter {
  static Future<File> convert({
    required String inputPptxPath,
    required String outputPdfPath,
    Function(String stage)? onProgress,
  }) async {
    onProgress?.call('Reading PowerPoint presentation...');
    final bytes = await File(inputPptxPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final pdf = pw.Document();
    final slideFiles = archive.files.where((f) => RegExp(r'ppt/slides/slide\d+\.xml').hasMatch(f.name)).toList();
    slideFiles.sort((a, b) => a.name.compareTo(b.name));

    if (slideFiles.isEmpty) {
      throw Exception('Invalid PPTX format: no slides found.');
    }

    onProgress?.call('Converting slides to PDF pages...');
    int slideIndex = 1;
    for (final slideFile in slideFiles) {
      final xmlContent = utf8.decode(slideFile.content as List<int>);
      final document = XmlDocument.parse(xmlContent);

      final textElements = document
          .findAllElements('a:t')
          .map((e) => _cleanText(e.innerText))
          .where((t) => t.trim().isNotEmpty)
          .toList();

      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(16 * 72.0, 9 * 72.0), // 16:9 widescreen ratio
          margin: const pw.EdgeInsets.all(32),
          build: (context) => pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Slide $slideIndex', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                    pw.Text('TK Office Presentation', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
                  ],
                ),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 16),
                if (textElements.isNotEmpty) ...[
                  pw.Text(
                    textElements.first,
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                  ),
                  pw.SizedBox(height: 16),
                  ...textElements.skip(1).map(
                        (t) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('• ', style: const pw.TextStyle(fontSize: 14, color: PdfColors.indigo700)),
                              pw.Expanded(
                                child: pw.Text(t, style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey800)),
                              ),
                            ],
                          ),
                        ),
                      ),
                ] else ...[
                  pw.Text('Empty Slide', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey600)),
                ],
              ],
            ),
          ),
        ),
      );
      slideIndex++;
    }

    onProgress?.call('Finalizing PDF slides...');
    final outputFile = File(outputPdfPath);
    await outputFile.writeAsBytes(await pdf.save());
    return outputFile;
  }

  static String _cleanText(String input) {
    return input
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('…', '...')
        .replaceAll('•', '*')
        .replaceAll('\u2022', '*')
        .replaceAll('\u00A0', ' ');
  }
}
