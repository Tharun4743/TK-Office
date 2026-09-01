import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';

class DocxToPdfConverter {
  static Future<File> convert({
    required String inputDocxPath,
    required String outputPdfPath,
    Function(String stage)? onProgress,
  }) async {
    onProgress?.call('Reading DOCX structure...');
    final bytes = await File(inputDocxPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? docXmlFile;
    for (final file in archive) {
      if (file.name == 'word/document.xml') {
        docXmlFile = file;
        break;
      }
    }

    if (docXmlFile == null) {
      throw Exception('Invalid DOCX format: word/document.xml not found.');
    }

    onProgress?.call('Parsing document text & paragraphs...');
    final xmlContent = utf8.decode(docXmlFile.content as List<int>);
    final document = XmlDocument.parse(xmlContent);

    final pdf = pw.Document();
    final List<pw.Widget> pdfElements = [];

    final paragraphs = document.findAllElements('w:p');
    for (final p in paragraphs) {
      final List<pw.InlineSpan> spans = [];
      final runs = p.findElements('w:r');

      for (final r in runs) {
        final textElements = r.findElements('w:t');
        final rawText = textElements.map((e) => e.innerText).join('');
        final text = _cleanPdfText(rawText);
        if (text.isEmpty) continue;

        final isBold = r.findElements('w:rPr').any((rPr) => rPr.findElements('w:b').isNotEmpty);
        final isItalic = r.findElements('w:rPr').any((rPr) => rPr.findElements('w:i').isNotEmpty);

        spans.add(
          pw.TextSpan(
            text: text,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontStyle: isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
            ),
          ),
        );
      }

      if (spans.isNotEmpty) {
        pdfElements.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.RichText(text: pw.TextSpan(children: spans)),
          ),
        );
      }
    }

    // Parse Tables if present
    final tables = document.findAllElements('w:tbl');
    for (final tbl in tables) {
      final List<pw.TableRow> tableRows = [];
      final rows = tbl.findElements('w:tr');

      for (final r in rows) {
        final cells = r.findElements('w:tc');
        final List<pw.Widget> cellWidgets = [];

        for (final c in cells) {
          final text = c.findAllElements('w:t').map((t) => t.innerText).join(' ');
          cellWidgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
            ),
          );
        }

        if (cellWidgets.isNotEmpty) {
          tableRows.add(pw.TableRow(children: cellWidgets));
        }
      }

      if (tableRows.isNotEmpty) {
        pdfElements.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              children: tableRows,
            ),
          ),
        );
      }
    }

    if (pdfElements.isEmpty) {
      pdfElements.add(pw.Text('Empty document', style: const pw.TextStyle(fontSize: 12)));
    }

    onProgress?.call('Generating PDF document...');
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) => pdfElements,
      ),
    );

    final outputFile = File(outputPdfPath);
    await outputFile.writeAsBytes(await pdf.save());
    return outputFile;
  }

  static String _cleanPdfText(String input) {
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
