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

      // 1. Parse image relationships (word/_rels/document.xml.rels)
      final Map<String, String> rIdToMedia = {};
      final relsFile = archive.findFile('word/_rels/document.xml.rels');
      if (relsFile != null) {
        try {
          final relsXml = utf8.decode(relsFile.content as List<int>);
          final relsDoc = XmlDocument.parse(relsXml);
          for (final rel in relsDoc.findAllElements('Relationship')) {
            final id = rel.getAttribute('Id') ?? '';
            final target = rel.getAttribute('Target') ?? '';
            final type = rel.getAttribute('Type') ?? '';
            if (type.contains('image') || target.contains('media/')) {
              final normalized = target.startsWith('media/')
                  ? 'word/$target'
                  : (target.startsWith('/') ? target.substring(1) : 'word/$target');
              rIdToMedia[id] = normalized;
            }
          }
        } catch (_) {}
      }

      final content = utf8.decode(documentXmlFile.content as List<int>);
      final document = XmlDocument.parse(content);
      final delta = Delta();

      final body = document.findAllElements('w:body').firstOrNull ?? document.rootElement;

      for (final child in body.children.whereType<XmlElement>()) {
        final tag = child.name.local;
        if (tag == 'p') {
          _parseParagraph(child, delta, archive, rIdToMedia);
        } else if (tag == 'tbl') {
          _parseTable(child, delta, archive, rIdToMedia);
        }
      }

      if (delta.isEmpty) {
        delta.insert('\n');
      }
      return delta;
    } catch (e) {
      return Delta()..insert('Error reading DOCX file: $e\n');
    }
  }

  static void _parseParagraph(
    XmlElement p,
    Delta delta,
    Archive archive,
    Map<String, String> rIdToMedia,
  ) {
    // Paragraph-level properties
    final pPr = p.findElements('w:pPr').firstOrNull;
    final pStyle = pPr?.findElements('w:pStyle').firstOrNull?.getAttribute('w:val')?.toLowerCase();
    final jc = pPr?.findElements('w:jc').firstOrNull?.getAttribute('w:val');
    final numPr = pPr?.findElements('w:numPr').firstOrNull;

    Map<String, dynamic>? blockAttr;
    if (pStyle != null) {
      if (pStyle.contains('heading1') || pStyle == '1' || pStyle == 'title') {
        blockAttr = {'header': 1};
      } else if (pStyle.contains('heading2') || pStyle == '2' || pStyle == 'subtitle') {
        blockAttr = {'header': 2};
      } else if (pStyle.contains('heading3') || pStyle == '3') {
        blockAttr = {'header': 3};
      }
    }

    if (numPr != null) {
      blockAttr ??= {};
      final numId = numPr.findElements('w:numId').firstOrNull?.getAttribute('w:val');
      if (numId == '1' || numId == '2') {
        blockAttr['list'] = 'bullet';
      } else {
        blockAttr['list'] = 'ordered';
      }
    }

    if (jc != null) {
      blockAttr ??= {};
      if (jc == 'center') blockAttr['align'] = 'center';
      if (jc == 'right' || jc == 'end') blockAttr['align'] = 'right';
      if (jc == 'both') blockAttr['align'] = 'justify';
    }

    for (final childNode in p.children.whereType<XmlElement>()) {
      final childTag = childNode.name.local;

      if (childTag == 'r') {
        final rPr = childNode.findElements('w:rPr').firstOrNull;
        final isBold = rPr?.findElements('w:b').isNotEmpty ?? false;
        final isItalic = rPr?.findElements('w:i').isNotEmpty ?? false;
        final isUnderline = rPr?.findElements('w:u').isNotEmpty ?? false;
        final isStrike = rPr?.findElements('w:strike').isNotEmpty ?? false;

        // Font color
        final colorVal = rPr?.findElements('w:color').firstOrNull?.getAttribute('w:val');
        String? hexColor;
        if (colorVal != null && colorVal != 'auto' && colorVal.length == 6) {
          hexColor = '#$colorVal';
        }

        final Map<String, dynamic> attributes = {};
        if (isBold) attributes['bold'] = true;
        if (isItalic) attributes['italic'] = true;
        if (isUnderline) attributes['underline'] = true;
        if (isStrike) attributes['strike'] = true;
        if (hexColor != null) attributes['color'] = hexColor;

        // Check for text
        for (final runChild in childNode.children.whereType<XmlElement>()) {
          final runTag = runChild.name.local;
          if (runTag == 't') {
            final text = runChild.innerText;
            if (text.isNotEmpty) {
              delta.insert(text, attributes.isNotEmpty ? attributes : null);
            }
          } else if (runTag == 'br' || runTag == 'cr') {
            delta.insert('\n', attributes.isNotEmpty ? attributes : null);
          } else if (runTag == 'tab') {
            delta.insert('    ', attributes.isNotEmpty ? attributes : null);
          } else if (runTag == 'drawing' || runTag == 'pict') {
            _parseDrawingInRun(runChild, delta, archive, rIdToMedia);
          }
        }
      } else if (childTag == 'hyperlink') {
        for (final r in childNode.findElements('w:r')) {
          final text = r.findElements('w:t').map((e) => e.innerText).join('');
          if (text.isNotEmpty) {
            delta.insert(text, {'color': '#1E40AF', 'underline': true});
          }
        }
      }
    }

    // End paragraph with block attributes
    delta.insert('\n', blockAttr);
  }

  static void _parseDrawingInRun(
    XmlElement drawing,
    Delta delta,
    Archive archive,
    Map<String, String> rIdToMedia,
  ) {
    final blip = drawing.findAllElements('a:blip').firstOrNull;
    final rId = blip?.getAttribute('r:embed') ?? blip?.getAttribute('rEmbed') ?? '';
    if (rId.isNotEmpty && rIdToMedia.containsKey(rId)) {
      // In Quill delta, images are represented as embeds
      delta.insert(' [Image] ');
    }
  }

  static void _parseTable(
    XmlElement tbl,
    Delta delta,
    Archive archive,
    Map<String, String> rIdToMedia,
  ) {
    delta.insert('\n');
    final rows = tbl.findElements('w:tr').toList();
    for (var rIdx = 0; rIdx < rows.length; rIdx++) {
      final row = rows[rIdx];
      final cells = row.findElements('w:tc').toList();
      final cellTexts = <String>[];

      for (final cell in cells) {
        final paragraphs = cell.findElements('w:p');
        final textList = <String>[];
        for (final p in paragraphs) {
          final t = p.findAllElements('w:t').map((e) => e.innerText).join('');
          if (t.trim().isNotEmpty) textList.add(t.trim());
        }
        cellTexts.add(textList.join(' '));
      }

      if (cellTexts.isNotEmpty) {
        // Render table row clearly formatted with vertical bar dividers
        final rowContent = '│  ${cellTexts.join('  │  ')}  │';
        final isHeader = rIdx == 0;
        delta.insert(rowContent, isHeader ? {'bold': true} : null);
        delta.insert('\n');
      }
    }
    delta.insert('\n');
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
