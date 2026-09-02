import 'dart:convert';
import 'dart:io';
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

    final body = document.findAllElements('w:body').firstOrNull ?? document.rootElement;

    for (final node in body.children.whereType<XmlElement>()) {
      if (node.name.local == 'p') {
        final List<pw.InlineSpan> spans = [];
        final runs = node.findElements('w:r');

        for (final r in runs) {
          final textElements = r.findElements('w:t');
          final rawText = textElements.map((e) => e.innerText).join('');
          final text = _cleanPdfText(rawText);
          if (text.isEmpty) continue;

          final isBold = r.findElements('w:rPr').any((rPr) => rPr.findElements('w:b').isNotEmpty);
          final isItalic = r.findElements('w:rPr').any((rPr) => rPr.findElements('w:i').isNotEmpty);
          final isUnderline = r.findElements('w:rPr').any((rPr) => rPr.findElements('w:u').isNotEmpty);
          final isStrike = r.findElements('w:rPr').any((rPr) => rPr.findElements('w:strike').isNotEmpty);

          spans.add(
            pw.TextSpan(
              text: text,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                fontStyle: isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
                decoration: isUnderline
                    ? pw.TextDecoration.underline
                    : (isStrike ? pw.TextDecoration.lineThrough : pw.TextDecoration.none),
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
      } else if (node.name.local == 'tbl') {
        final List<pw.TableRow> tableRows = [];
        final rows = node.findElements('w:tr');

        for (final r in rows) {
          final cells = r.findElements('w:tc');
          final List<pw.Widget> cellWidgets = [];

          for (final c in cells) {
            final text = c.findAllElements('w:t').map((t) => t.innerText).join(' ');
            cellWidgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(_cleanPdfText(text), style: const pw.TextStyle(fontSize: 10)),
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
