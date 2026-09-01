import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:xml/xml.dart';

class DocxService {
  /// Converts a DOCX file from disk into a Quill Delta
  static Future<Delta> importDocx(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return Delta()..insert('\n');
    }

    final bytes = await file.readAsBytes();
    return importDocxBytes(bytes);
  }

  static Delta importDocxBytes(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentXmlFile = archive.findFile('word/document.xml');

      if (documentXmlFile == null) {
        return Delta()..insert('Could not read document contents.\n');
      }

      final content = utf8.decode(documentXmlFile.content as List<int>);
      final document = XmlDocument.parse(content);
      final delta = Delta();

      final paragraphs = document.findAllElements('w:p');
      for (final p in paragraphs) {
        final runs = p.findAllElements('w:r');
        
        // Paragraph level properties
        final pPr = p.findElements('w:pPr').firstOrNull;
        final pStyle = pPr?.findElements('w:pStyle').firstOrNull?.getAttribute('w:val');
        final jc = pPr?.findElements('w:jc').firstOrNull?.getAttribute('w:val');

        Map<String, dynamic>? blockAttr;
        if (pStyle != null) {
          if (pStyle.toLowerCase().contains('heading1') || pStyle == '1') {
            blockAttr = {'header': 1};
          } else if (pStyle.toLowerCase().contains('heading2') || pStyle == '2') {
            blockAttr = {'header': 2};
          } else if (pStyle.toLowerCase().contains('heading3') || pStyle == '3') {
            blockAttr = {'header': 3};
          }
        }
        if (jc != null) {
          blockAttr ??= {};
          if (jc == 'center') blockAttr['align'] = 'center';
          if (jc == 'right') blockAttr['align'] = 'right';
          if (jc == 'both') blockAttr['align'] = 'justify';
        }

        for (final r in runs) {
          final t = r.findAllElements('w:t').map((e) => e.innerText).join('');
          if (t.isEmpty) continue;

          final rPr = r.findElements('w:rPr').firstOrNull;
          final isBold = rPr?.findElements('w:b').isNotEmpty ?? false;
          final isItalic = rPr?.findElements('w:i').isNotEmpty ?? false;
          final isUnderline = rPr?.findElements('w:u').isNotEmpty ?? false;
          final isStrike = rPr?.findElements('w:strike').isNotEmpty ?? false;

          final Map<String, dynamic> attributes = {};
          if (isBold) attributes['bold'] = true;
          if (isItalic) attributes['italic'] = true;
          if (isUnderline) attributes['underline'] = true;
          if (isStrike) attributes['strike'] = true;

          delta.insert(t, attributes.isNotEmpty ? attributes : null);
        }

        // End paragraph
        delta.insert('\n', blockAttr);
      }

      if (delta.isEmpty) {
        delta.insert('\n');
      }
      return delta;
    } catch (e) {
      return Delta()..insert('Error reading DOCX file: $e\n');
    }
  }

  /// Exports a Quill Delta into standard OpenXML (.docx) bytes
  static Uint8List exportToDocx(Delta delta) {
    final archive = Archive();

    // 1. [Content_Types].xml
    const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';
    final contentTypesBytes = utf8.encode(contentTypesXml);
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesBytes.length, contentTypesBytes));

    // 2. _rels/.rels
    const rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    final rootRelsBytes = utf8.encode(rootRelsXml);
    archive.addFile(ArchiveFile('_rels/.rels', rootRelsBytes.length, rootRelsBytes));

    // 3. word/_rels/document.xml.rels  (REQUIRED by OOXML spec)
    const wordRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>''';
    final wordRelsBytes = utf8.encode(wordRelsXml);
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', wordRelsBytes.length, wordRelsBytes));

    // 4. word/document.xml
    final docXmlBuffer = StringBuffer();
    docXmlBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    docXmlBuffer.writeln('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
    docXmlBuffer.writeln('  <w:body>');

    final operations = delta.toList();
    var currentParagraphRuns = <String>[];
    Map<String, dynamic>? currentParagraphAttr;

    void flushParagraph() {
      docXmlBuffer.writeln('    <w:p>');
      
      // Paragraph properties
      if (currentParagraphAttr != null) {
        docXmlBuffer.writeln('      <w:pPr>');
        if (currentParagraphAttr!.containsKey('header')) {
          final level = currentParagraphAttr!['header'];
          docXmlBuffer.writeln('        <w:pStyle w:val="Heading$level"/>');
        }
        if (currentParagraphAttr!.containsKey('align')) {
          final align = currentParagraphAttr!['align'];
          String wVal = 'left';
          if (align == 'center') wVal = 'center';
          if (align == 'right') wVal = 'right';
          if (align == 'justify') wVal = 'both';
          docXmlBuffer.writeln('        <w:jc w:val="$wVal"/>');
        }
        docXmlBuffer.writeln('      </w:pPr>');
      }

      for (final runXml in currentParagraphRuns) {
        docXmlBuffer.write(runXml);
      }
      docXmlBuffer.writeln('    </w:p>');
      currentParagraphRuns = [];
      currentParagraphAttr = null;
    }

    for (final op in operations) {
      final data = op.data;
      if (data is String) {
        final lines = data.split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.isNotEmpty) {
            final runBuffer = StringBuffer();
            runBuffer.writeln('      <w:r>');
            
            // Run properties
            final attrs = op.attributes;
            if (attrs != null && attrs.isNotEmpty) {
              runBuffer.writeln('        <w:rPr>');
              if (attrs['bold'] == true) runBuffer.writeln('          <w:b/>');
              if (attrs['italic'] == true) runBuffer.writeln('          <w:i/>');
              if (attrs['underline'] == true) runBuffer.writeln('          <w:u w:val="single"/>');
              if (attrs['strike'] == true) runBuffer.writeln('          <w:strike/>');
              runBuffer.writeln('        </w:rPr>');
            }

            final escaped = _escapeXml(line);
            runBuffer.writeln('        <w:t xml:space="preserve">$escaped</w:t>');
            runBuffer.writeln('      </w:r>');
            currentParagraphRuns.add(runBuffer.toString());
          }

          if (i < lines.length - 1) {
            // Newline reached
            currentParagraphAttr = op.attributes;
            flushParagraph();
          }
        }
      }
    }

    if (currentParagraphRuns.isNotEmpty) {
      flushParagraph();
    }

    docXmlBuffer.writeln('  </w:body>');
    docXmlBuffer.writeln('</w:document>');

    final docXmlStr = docXmlBuffer.toString();
    final docXmlBytes = utf8.encode(docXmlStr);
    archive.addFile(ArchiveFile('word/document.xml', docXmlBytes.length, docXmlBytes));

    final encodedZip = ZipEncoder().encode(archive);
    return Uint8List.fromList(encodedZip ?? []);
  }

  static String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
