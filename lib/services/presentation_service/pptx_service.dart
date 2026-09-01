import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../../models/presentation_model.dart';

class PptxService {
  static Future<PresentationModel> importPptx(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return PresentationModel.empty();
    }

    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final List<SlideModel> slides = [];

      var slideIndex = 1;
      while (true) {
        final slideFile = archive.findFile('ppt/slides/slide$slideIndex.xml');
        if (slideFile == null) break;

        final content = utf8.decode(slideFile.content as List<int>);
        final doc = XmlDocument.parse(content);
        final elements = <SlideElement>[];

        // Find shapes and text
        final textElements = doc.findAllElements('a:t');
        var yOffset = 60.0;
        for (final t in textElements) {
          final text = t.innerText.trim();
          if (text.isNotEmpty) {
            elements.add(
              SlideElement(
                id: 'elem_${slideIndex}_${elements.length}',
                type: SlideElementType.text,
                x: 40,
                y: yOffset,
                width: 320,
                height: 40,
                content: text,
                fontSize: 16,
              ),
            );
            yOffset += 50.0;
          }
        }

        slides.add(
          SlideModel(
            id: 'slide_$slideIndex',
            title: 'Slide $slideIndex',
            elements: elements.isNotEmpty
                ? elements
                : [
                    SlideElement(
                      id: 'elem_${slideIndex}_0',
                      type: SlideElementType.text,
                      x: 40,
                      y: 60,
                      width: 320,
                      height: 50,
                      content: 'Slide $slideIndex',
                      fontSize: 22,
                    ),
                  ],
          ),
        );

        slideIndex++;
      }

      if (slides.isEmpty) {
        slides.add(SlideModel.titleSlide(id: 'slide_1'));
      }

      return PresentationModel(
        filePath: filePath,
        title: file.uri.pathSegments.last,
        slides: slides,
        lastModified: file.statSync().modified,
      );
    } catch (_) {
      return PresentationModel.empty(title: file.uri.pathSegments.last);
    }
  }

  static Uint8List exportToPptx(PresentationModel presentation) {
    final archive = Archive();

    // 1. [Content_Types].xml
    final contentTypesBuffer = StringBuffer();
    contentTypesBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    contentTypesBuffer.writeln('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">');
    contentTypesBuffer.writeln('  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>');
    contentTypesBuffer.writeln('  <Default Extension="xml" ContentType="application/xml"/>');
    contentTypesBuffer.writeln('  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>');

    for (var i = 1; i <= presentation.slides.length; i++) {
      contentTypesBuffer.writeln('  <Override PartName="/ppt/slides/slide$i.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>');
    }
    contentTypesBuffer.writeln('</Types>');

    final ctStr = contentTypesBuffer.toString();
    archive.addFile(ArchiveFile('[Content_Types].xml', ctStr.length, utf8.encode(ctStr)));

    // 2. _rels/.rels
    const rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', rootRelsXml.length, utf8.encode(rootRelsXml)));

    // 3. ppt/presentation.xml
    final presBuffer = StringBuffer();
    presBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    presBuffer.writeln('<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">');
    presBuffer.writeln('  <p:sldIdLst>');
    for (var i = 1; i <= presentation.slides.length; i++) {
      presBuffer.writeln('    <p:sldId id="${255 + i}" r:id="rId$i"/>');
    }
    presBuffer.writeln('  </p:sldIdLst>');
    presBuffer.writeln('</p:presentation>');

    final presStr = presBuffer.toString();
    archive.addFile(ArchiveFile('ppt/presentation.xml', presStr.length, utf8.encode(presStr)));

    // 4. ppt/_rels/presentation.xml.rels
    final presRelsBuffer = StringBuffer();
    presRelsBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    presRelsBuffer.writeln('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
    for (var i = 1; i <= presentation.slides.length; i++) {
      presRelsBuffer.writeln('  <Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide$i.xml"/>');
    }
    presRelsBuffer.writeln('</Relationships>');

    final presRelsStr = presRelsBuffer.toString();
    archive.addFile(ArchiveFile('ppt/_rels/presentation.xml.rels', presRelsStr.length, utf8.encode(presRelsStr)));

    // 5. Individual Slide XMLs
    for (var i = 0; i < presentation.slides.length; i++) {
      final slide = presentation.slides[i];
      final slideBuffer = StringBuffer();
      slideBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
      slideBuffer.writeln('<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">');
      slideBuffer.writeln('  <p:cSld>');
      slideBuffer.writeln('    <p:spTree>');
      slideBuffer.writeln('      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:grpSpPr/></p:nvGrpSpPr>');
      slideBuffer.writeln('      <p:grpSpPr/>');

      var spId = 2;
      for (final elem in slide.elements) {
        if (elem.type == SlideElementType.text) {
          final escapedText = elem.content
              .replaceAll('&', '&amp;')
              .replaceAll('<', '&lt;')
              .replaceAll('>', '&gt;');

          slideBuffer.writeln('      <p:sp>');
          slideBuffer.writeln('        <p:nvSpPr><p:cNvPr id="$spId" name="TextBox $spId"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>');
          slideBuffer.writeln('        <p:spPr><a:xfrm><a:off x="${(elem.x * 12700).toInt()}" y="${(elem.y * 12700).toInt()}"/><a:ext cx="${(elem.width * 12700).toInt()}" cy="${(elem.height * 12700).toInt()}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>');
          slideBuffer.writeln('        <p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr sz="${(elem.fontSize * 100).toInt()}" b="${elem.isBold ? 1 : 0}" i="${elem.isItalic ? 1 : 0}"/><a:t>$escapedText</a:t></a:r></a:p></p:txBody>');
          slideBuffer.writeln('      </p:sp>');
          spId++;
        }
      }

      slideBuffer.writeln('    </p:spTree>');
      slideBuffer.writeln('  </p:cSld>');
      slideBuffer.writeln('</p:sld>');

      final slideStr = slideBuffer.toString();
      archive.addFile(ArchiveFile('ppt/slides/slide${i + 1}.xml', slideStr.length, utf8.encode(slideStr)));
    }

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded ?? []);
  }
}
