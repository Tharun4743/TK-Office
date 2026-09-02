import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart' show Color, Colors, TextAlign;
import 'package:xml/xml.dart';
import '../../models/presentation_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PptxService
//  Parses .pptx (Open Packaging Convention ZIP) into PresentationModel.
//  Preserves: backgrounds, shapes, images, text with full formatting,
//             tables, connectors, charts (as labelled placeholders).
// ─────────────────────────────────────────────────────────────────────────────

class PptxService {
  // ── Standard OOXML EMU → logical-pixel divisor (1 pt = 12700 EMU)
  static const double _emuPerPx = 12700.0;
  // Standard 16:9 PPTX logical dimensions in px
  static const double _defaultW = 720.0;
  static const double _defaultH = 405.0;

  // Namespace prefixes are parsed via xml library's element local names

  // ─────────────────────────────────────────────────────────────
  //  PUBLIC: importPptx
  // ─────────────────────────────────────────────────────────────

  static Future<PresentationModel> importPptx(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return PresentationModel.empty();

    // Binary .ppt format — cannot parse with XML
    if (filePath.toLowerCase().endsWith('.ppt') &&
        !filePath.toLowerCase().endsWith('.pptx')) {
      return _binaryPptFallback(filePath);
    }

    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 1. Parse theme colors
      final themeColors = _parseTheme(archive);

      // 2. Parse presentation.xml for slide IDs and dimensions
      final presXml = _archiveText(archive, 'ppt/presentation.xml');
      double slideW = _defaultW;
      double slideH = _defaultH;
      if (presXml != null) {
        try {
          final presDoc = XmlDocument.parse(presXml);
          final sldSz = presDoc.findAllElements('p:sldSz').firstOrNull;
          if (sldSz != null) {
            final cx = double.tryParse(sldSz.getAttribute('cx') ?? '') ?? (slideW * _emuPerPx);
            final cy = double.tryParse(sldSz.getAttribute('cy') ?? '') ?? (slideH * _emuPerPx);
            slideW = cx / _emuPerPx;
            slideH = cy / _emuPerPx;
          }
        } catch (_) {}
      }

      // 3. Enumerate slide files in order
      final List<SlideModel> slides = [];
      var idx = 1;
      while (true) {
        final slideEntry = archive.findFile('ppt/slides/slide$idx.xml');
        if (slideEntry == null) break;

        final relsPath = 'ppt/slides/_rels/slide$idx.xml.rels';
        final slideRels = _archiveText(archive, relsPath);

        final slide = _parseSlide(
          slideXml: utf8.decode(slideEntry.content as List<int>),
          slideIndex: idx,
          archive: archive,
          slideRels: slideRels,
          themeColors: themeColors,
          slideW: slideW,
          slideH: slideH,
        );
        slides.add(slide);
        idx++;
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
    } catch (e) {
      // Parsing failed — return a single-slide fallback with error message
      return PresentationModel(
        filePath: filePath,
        title: file.uri.pathSegments.last,
        slides: [
          SlideModel(
            id: 'slide_1',
            title: 'Parse Error',
            elements: [
              SlideElement(
                id: 'err_0',
                type: SlideElementType.fallback,
                x: 40,
                y: 60,
                width: 640,
                height: 60,
                fallbackLabel: 'Could not fully parse this file.\n$e',
              ),
            ],
          ),
        ],
        lastModified: DateTime.now(),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Binary .ppt fallback
  // ─────────────────────────────────────────────────────────────

  static PresentationModel _binaryPptFallback(String filePath) {
    final name = File(filePath).uri.pathSegments.last;
    return PresentationModel(
      filePath: filePath,
      title: name,
      slides: [
        SlideModel(
          id: 'slide_1',
          title: name,
          elements: [
            SlideElement(
              id: 'info_0',
              type: SlideElementType.fallback,
              x: 60,
              y: 100,
              width: 600,
              height: 200,
              fallbackLabel:
                  'Legacy PPT (Binary) format\n\n'
                  'This file uses the old binary .ppt format which cannot be\n'
                  'parsed directly. Please open the file in Microsoft PowerPoint\n'
                  'and save it as .pptx, then re-open it here.',
            ),
          ],
        ),
      ],
      lastModified: File(filePath).existsSync() ? File(filePath).statSync().modified : DateTime.now(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Parse theme colors from ppt/theme/theme1.xml
  // ─────────────────────────────────────────────────────────────

  static Map<String, Color> _parseTheme(Archive archive) {
    final themeXml = _archiveText(archive, 'ppt/theme/theme1.xml');
    final Map<String, Color> colors = {
      // Sensible defaults matching the "Office" theme
      'dk1': Colors.black,
      'lt1': Colors.white,
      'dk2': const Color(0xFF44546A),
      'lt2': const Color(0xFFE7E6E6),
      'acc1': const Color(0xFF4472C4),
      'acc2': const Color(0xFFED7D31),
      'acc3': const Color(0xFFA9D18E),
      'acc4': const Color(0xFFFFC000),
      'acc5': const Color(0xFF5B9BD5),
      'acc6': const Color(0xFF70AD47),
    };

    if (themeXml == null) return colors;

    try {
      final doc = XmlDocument.parse(themeXml);
      // Map scheme element names to our keys
      const schemeMap = {
        'a:dk1': 'dk1',
        'a:lt1': 'lt1',
        'a:dk2': 'dk2',
        'a:lt2': 'lt2',
        'a:accent1': 'acc1',
        'a:accent2': 'acc2',
        'a:accent3': 'acc3',
        'a:accent4': 'acc4',
        'a:accent5': 'acc5',
        'a:accent6': 'acc6',
      };

      for (final entry in schemeMap.entries) {
        final el = doc.findAllElements(entry.key).firstOrNull;
        if (el == null) continue;
        final color = _parseColorElement(el.children.whereType<XmlElement>().firstOrNull, colors);
        if (color != null) colors[entry.value] = color;
      }
    } catch (_) {}

    return colors;
  }

  // ─────────────────────────────────────────────────────────────
  //  Parse a single slide XML
  // ─────────────────────────────────────────────────────────────

  static SlideModel _parseSlide({
    required String slideXml,
    required int slideIndex,
    required Archive archive,
    String? slideRels,
    required Map<String, Color> themeColors,
    required double slideW,
    required double slideH,
  }) {
    String? layoutPath;
    final Map<String, String> rIdToMedia = {};
    if (slideRels != null) {
      try {
        final relsDoc = XmlDocument.parse(slideRels);
        for (final rel in relsDoc.findAllElements('Relationship')) {
          final id = rel.getAttribute('Id') ?? '';
          final target = rel.getAttribute('Target') ?? '';
          final type = rel.getAttribute('Type') ?? '';
          if (type.contains('slideLayout')) {
            layoutPath = target.startsWith('..') ? 'ppt/${target.substring(3)}' : 'ppt/slides/$target';
          } else if (type.contains('image') || target.contains('media/')) {
            // Target is relative to slides/: ../media/image1.png → ppt/media/image1.png
            final normalized = target.startsWith('..') ? 'ppt/${target.substring(3)}' : 'ppt/slides/$target';
            rIdToMedia[id] = normalized;
          }
        }
      } catch (_) {}
    }

    final doc = XmlDocument.parse(slideXml);
    final List<SlideElement> elements = [];

    // ── Background
    Color bgColor = Colors.white;
    List<Color> bgGradient = [];
    double bgGradientAngle = 0;
    Uint8List? bgImageBytes;

    final bgPr = doc.findAllElements('p:bg').firstOrNull?.findElements('p:bgPr').firstOrNull;
    if (bgPr != null) {
      final solidFill = bgPr.findElements('a:solidFill').firstOrNull;
      if (solidFill != null) {
        bgColor = _parseColorElement(solidFill.children.whereType<XmlElement>().firstOrNull, themeColors) ?? Colors.white;
      }
      final gradFill = bgPr.findElements('a:gradFill').firstOrNull;
      if (gradFill != null) {
        final result = _parseGradFill(gradFill, themeColors);
        bgGradient = result.$1;
        bgGradientAngle = result.$2;
        if (bgGradient.isNotEmpty) bgColor = bgGradient.first;
      }
      final blipFill = bgPr.findElements('a:blipFill').firstOrNull;
      if (blipFill != null) {
        final blip = blipFill.findElements('a:blip').firstOrNull;
        final rId = blip?.getAttribute('r:embed') ?? blip?.getAttribute('rEmbed') ?? '';
        if (rId.isNotEmpty && rIdToMedia.containsKey(rId)) {
          bgImageBytes = _archiveBytes(archive, rIdToMedia[rId]!);
        }
      }
    }

    // ── Inherit Layout / Master background and static template elements
    XmlDocument? layoutDoc;
    if (layoutPath != null) {
      final layoutXml = _archiveText(archive, layoutPath);
      if (layoutXml != null) {
        try {
          layoutDoc = XmlDocument.parse(layoutXml);
        } catch (_) {}
      }

      _parseLayoutAndMasterElements(
        layoutPath: layoutPath,
        slideIndex: slideIndex,
        archive: archive,
        themeColors: themeColors,
        elements: elements,
        setBgColorIfDefault: (color) {
          if (bgColor == Colors.white && bgGradient.isEmpty && bgImageBytes == null) {
            bgColor = color;
          }
        },
        setBgImageIfDefault: (bytes) {
          bgImageBytes ??= bytes;
        },
      );
    }

    // ── Shape tree
    final spTree = doc.findAllElements('p:spTree').firstOrNull;
    if (spTree != null) {
      var zOrder = 0;
      for (final child in spTree.childElements) {
        final tag = child.name.local;
        switch (tag) {
          case 'sp':
            final elem = _parseShape(child, slideIndex, zOrder, themeColors, layoutDoc: layoutDoc);
            if (elem != null) elements.add(elem);
            break;
          case 'pic':
            final elem = _parsePic(child, slideIndex, zOrder, archive, rIdToMedia);
            if (elem != null) elements.add(elem);
            break;
          case 'graphicFrame':
            final elem = _parseGraphicFrame(child, slideIndex, zOrder, themeColors);
            if (elem != null) elements.add(elem);
            break;
          case 'cxnSp':
            final elem = _parseCxnSp(child, slideIndex, zOrder, themeColors);
            if (elem != null) elements.add(elem);
            break;
          case 'grpSp':
            final children = _parseGrpSp(child, slideIndex, zOrder, archive, rIdToMedia, themeColors);
            elements.addAll(children);
            break;
        }
        zOrder++;
      }
    }

    // Derive slide title from first bold/large text or placeholder
    String title = 'Slide $slideIndex';
    final titlePh = elements.where((e) =>
        e.type == SlideElementType.text && e.paragraphs.isNotEmpty &&
        (e.isBold || e.fontSize >= 24)).firstOrNull;
    if (titlePh != null) {
      title = titlePh.paragraphs.first.plainText.trim();
      if (title.length > 60) title = '${title.substring(0, 57)}…';
    }
    if (title.isEmpty) title = 'Slide $slideIndex';

    // Speaker notes skipped — would need notes/notesSlide$idx.xml parsing
    const notes = '';

    return SlideModel(
      id: 'slide_$slideIndex',
      title: title,
      backgroundColor: bgColor,
      backgroundGradientColors: bgGradient,
      backgroundGradientAngle: bgGradientAngle,
      backgroundImageBytes: bgImageBytes,
      slideWidth: slideW,
      slideHeight: slideH,
      elements: elements,
      speakerNotes: notes,
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Parse static non-placeholder elements from slideLayout & master
  // ─────────────────────────────────────────────────────────────

  static void _parseLayoutAndMasterElements({
    required String layoutPath,
    required int slideIndex,
    required Archive archive,
    required Map<String, Color> themeColors,
    required List<SlideElement> elements,
    required void Function(Color) setBgColorIfDefault,
    required void Function(Uint8List) setBgImageIfDefault,
  }) {
    final layoutXml = _archiveText(archive, layoutPath);
    if (layoutXml == null) return;

    try {
      final layoutDoc = XmlDocument.parse(layoutXml);

      // 1. Resolve layout rels
      final layoutFileName = layoutPath.split('/').last;
      final layoutRelsPath = 'ppt/slideLayouts/_rels/$layoutFileName.rels';
      final layoutRels = _archiveText(archive, layoutRelsPath);

      final Map<String, String> layoutRIdToMedia = {};
      String? masterPath;

      if (layoutRels != null) {
        try {
          final relsDoc = XmlDocument.parse(layoutRels);
          for (final rel in relsDoc.findAllElements('Relationship')) {
            final id = rel.getAttribute('Id') ?? '';
            final target = rel.getAttribute('Target') ?? '';
            final type = rel.getAttribute('Type') ?? '';
            if (type.contains('slideMaster')) {
              masterPath = target.startsWith('..') ? 'ppt/${target.substring(3)}' : 'ppt/slideLayouts/$target';
            } else if (type.contains('image') || target.contains('media/')) {
              final normalized = target.startsWith('..') ? 'ppt/${target.substring(3)}' : 'ppt/slideLayouts/$target';
              layoutRIdToMedia[id] = normalized;
            }
          }
        } catch (_) {}
      }

      // 2. Check layout background
      final bgPr = layoutDoc.findAllElements('p:bg').firstOrNull?.findElements('p:bgPr').firstOrNull;
      if (bgPr != null) {
        final solidFill = bgPr.findElements('a:solidFill').firstOrNull;
        if (solidFill != null) {
          final c = _parseColorElement(solidFill.children.whereType<XmlElement>().firstOrNull, themeColors);
          if (c != null) setBgColorIfDefault(c);
        }
        final blipFill = bgPr.findElements('a:blipFill').firstOrNull;
        if (blipFill != null) {
          final blip = blipFill.findElements('a:blip').firstOrNull;
          final rId = blip?.getAttribute('r:embed') ?? blip?.getAttribute('rEmbed') ?? '';
          if (rId.isNotEmpty && layoutRIdToMedia.containsKey(rId)) {
            final bytes = _archiveBytes(archive, layoutRIdToMedia[rId]!);
            if (bytes != null) setBgImageIfDefault(bytes);
          }
        }
      }

      // 3. Parse non-placeholder shapes/images from layout spTree
      final spTree = layoutDoc.findAllElements('p:spTree').firstOrNull;
      if (spTree != null) {
        var zOrder = 0;
        for (final child in spTree.childElements) {
          final tag = child.name.local;
          // Only take non-placeholder elements (template branding, logos, shapes)
          final isPlaceholder = child.findAllElements('p:ph').isNotEmpty;
          if (!isPlaceholder) {
            switch (tag) {
              case 'sp':
                final elem = _parseShape(child, slideIndex, 9000 + zOrder, themeColors);
                if (elem != null) elements.add(elem);
                break;
              case 'pic':
                final elem = _parsePic(child, slideIndex, 9000 + zOrder, archive, layoutRIdToMedia);
                if (elem != null) elements.add(elem);
                break;
            }
          }
          zOrder++;
        }
      }

      // 4. If masterPath exists, check master background
      if (masterPath != null) {
        final masterXml = _archiveText(archive, masterPath);
        if (masterXml != null) {
          try {
            final masterDoc = XmlDocument.parse(masterXml);
            final mBgPr = masterDoc.findAllElements('p:bg').firstOrNull?.findElements('p:bgPr').firstOrNull;
            if (mBgPr != null) {
              final solidFill = mBgPr.findElements('a:solidFill').firstOrNull;
              if (solidFill != null) {
                final c = _parseColorElement(solidFill.children.whereType<XmlElement>().firstOrNull, themeColors);
                if (c != null) setBgColorIfDefault(c);
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────
  //  Parse <p:sp> — text box or shape
  // ─────────────────────────────────────────────────────────────

  static SlideElement? _parseShape(
    XmlElement sp,
    int slideIndex,
    int zOrder,
    Map<String, Color> theme, {
    XmlDocument? layoutDoc,
  }) {
    final id = 'sl${slideIndex}_sp$zOrder';
    var xfrmEl = sp.findAllElements('a:xfrm').firstOrNull;

    // Inherit xfrm from layout placeholder if omitted on slide shape
    if (xfrmEl == null && layoutDoc != null) {
      final ph = sp.findAllElements('p:ph').firstOrNull;
      if (ph != null) {
        final phType = ph.getAttribute('type') ?? '';
        final phIdx = ph.getAttribute('idx') ?? '';

        for (final lSp in layoutDoc.findAllElements('p:sp')) {
          final lPh = lSp.findAllElements('p:ph').firstOrNull;
          if (lPh != null) {
            final lType = lPh.getAttribute('type') ?? '';
            final lIdx = lPh.getAttribute('idx') ?? '';
            if ((phType.isNotEmpty && phType == lType) ||
                (phIdx.isNotEmpty && phIdx == lIdx) ||
                (phType.isEmpty && phIdx.isEmpty && lType.contains('Title'))) {
              xfrmEl = lSp.findAllElements('a:xfrm').firstOrNull;
              if (xfrmEl != null) break;
            }
          }
        }
      }
    }

    final xfrm = _parseXfrm(xfrmEl);

    // Fill
    Color? fillColor;
    final spPr = sp.findElements('p:spPr').firstOrNull;
    if (spPr != null) {
      fillColor = _parseFillColor(spPr, theme);
    }

    // Stroke
    Color? strokeColor;
    double strokeWidth = 0;
    final ln = spPr?.findElements('a:ln').firstOrNull;
    if (ln != null) {
      strokeWidth = (double.tryParse(ln.getAttribute('w') ?? '') ?? 0) / _emuPerPx;
      final lnFill = ln.findElements('a:solidFill').firstOrNull;
      if (lnFill != null) {
        strokeColor = _parseColorElement(lnFill.children.whereType<XmlElement>().firstOrNull, theme);
      }
    }

    // Shape geometry
    SlideShapeType shapeType = SlideShapeType.rectangle;
    final prstGeom = spPr?.findElements('a:prstGeom').firstOrNull;
    if (prstGeom != null) {
      shapeType = _mapPreset(prstGeom.getAttribute('prst') ?? '');
    }

    // Text body
    final txBody = sp.findAllElements('p:txBody').firstOrNull;
    final paragraphs = txBody != null ? _parseTxBody(txBody, theme) : <TextParagraph>[];

    // Legacy plain content for editor compatibility
    final plainText = paragraphs.map((p) => p.plainText).join('\n');
    final firstRun = paragraphs.firstOrNull?.runs.firstOrNull;

    // Determine if this is text-box or shape.
    // CRITICAL FIX: Any element with text content MUST be typed as text
    // so it goes through the rich text renderer. Shapes with both fill AND
    // text (e.g. coloured title boxes) must also show their text.
    final isTxBox = sp.findAllElements('p:cNvSpPr').any(
      (e) => e.getAttribute('txBox') == '1',
    );
    final hasText = paragraphs.any((p) => p.plainText.isNotEmpty);
    // Always use text type when there is text content so it renders correctly.
    // The text renderer already handles fillColor for the background.
    final type = (hasText || isTxBox)
        ? SlideElementType.text
        : SlideElementType.shape;

    return SlideElement(
      id: id,
      type: type,
      x: xfrm['x']!,
      y: xfrm['y']!,
      width: xfrm['w']!,
      height: xfrm['h']!,
      rotation: xfrm['rot']!,
      shapeType: shapeType,
      fillColor: fillColor,
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
      content: plainText,
      paragraphs: paragraphs,
      fontSize: firstRun?.fontSize ?? 18.0,
      isBold: firstRun?.isBold ?? false,
      isItalic: firstRun?.isItalic ?? false,
      textColor: firstRun?.color ?? Colors.black87,
      align: paragraphs.firstOrNull?.align ?? TextAlign.left,
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Parse <p:pic> — embedded image
  // ─────────────────────────────────────────────────────────────

  static SlideElement? _parsePic(
    XmlElement pic,
    int slideIndex,
    int zOrder,
    Archive archive,
    Map<String, String> rIdToMedia,
  ) {
    final id = 'sl${slideIndex}_pic$zOrder';
    final xfrm = _parseXfrm(pic.findAllElements('a:xfrm').firstOrNull);

    final blip = pic.findAllElements('a:blip').firstOrNull;
    final rId = blip?.getAttribute('r:embed') ?? blip?.getAttribute('rEmbed') ?? '';
    Uint8List? imgBytes;
    if (rId.isNotEmpty && rIdToMedia.containsKey(rId)) {
      imgBytes = _archiveBytes(archive, rIdToMedia[rId]!);
    }

    if (imgBytes == null) return null;

    return SlideElement(
      id: id,
      type: SlideElementType.image,
      x: xfrm['x']!,
      y: xfrm['y']!,
      width: xfrm['w']!,
      height: xfrm['h']!,
      rotation: xfrm['rot']!,
      imageBytes: imgBytes,
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Parse <p:graphicFrame> — table or chart
  // ─────────────────────────────────────────────────────────────

  static SlideElement? _parseGraphicFrame(
    XmlElement gf,
    int slideIndex,
    int zOrder,
    Map<String, Color> theme,
  ) {
    final id = 'sl${slideIndex}_gf$zOrder';
    final xfrm = _parseXfrm(gf.findAllElements('a:xfrm').firstOrNull);

    // Table
    final tbl = gf.findAllElements('a:tbl').firstOrNull;
    if (tbl != null) {
      return _parseTable(tbl, id, xfrm, theme);
    }

    // Chart — render as placeholder
    final chartTitle = gf.findAllElements('c:tx').firstOrNull?.innerText.trim() ??
        gf.findAllElements('c:title').firstOrNull?.innerText.trim() ??
        'Chart';

    return SlideElement(
      id: id,
      type: SlideElementType.fallback,
      x: xfrm['x']!,
      y: xfrm['y']!,
      width: xfrm['w']!.clamp(60, 9999),
      height: xfrm['h']!.clamp(40, 9999),
      fallbackLabel: '📊 $chartTitle',
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Parse <a:tbl> — DrawingML table
  // ─────────────────────────────────────────────────────────────

  static SlideElement _parseTable(
    XmlElement tbl,
    String id,
    Map<String, double> xfrm,
    Map<String, Color> theme,
  ) {
    // Column widths
    final colWidths = tbl
        .findElements('a:tblGrid')
        .firstOrNull
        ?.findElements('a:gridCol')
        .map((gc) => (double.tryParse(gc.getAttribute('w') ?? '') ?? 914400) / _emuPerPx)
        .toList() ?? [];

    final List<List<TableCell>> rows = [];
    final List<double> rowHeights = [];

    for (final tr in tbl.findElements('a:tr')) {
      final rowH = (double.tryParse(tr.getAttribute('h') ?? '') ?? 457200) / _emuPerPx;
      rowHeights.add(rowH);
      final List<TableCell> row = [];

      for (final tc in tr.findElements('a:tc')) {
        Color? cellFill;
        final tcPr = tc.findElements('a:tcPr').firstOrNull;
        if (tcPr != null) {
          cellFill = _parseFillColor(tcPr, theme);
        }
        // Table cell borders
        Color borderColor = Colors.black38;
        double borderW = 1.0;
        final lnL = tcPr?.findElements('a:lnL').firstOrNull;
        if (lnL != null) {
          borderW = (double.tryParse(lnL.getAttribute('w') ?? '') ?? 12700) / _emuPerPx;
          final lnSolid = lnL.findElements('a:solidFill').firstOrNull;
          if (lnSolid != null) {
            borderColor = _parseColorElement(lnSolid.children.whereType<XmlElement>().firstOrNull, theme) ?? Colors.black38;
          }
        }

        final paragraphs = tc.findElements('a:txBody').firstOrNull != null
            ? _parseTxBody(tc.findElements('a:txBody').first, theme)
            : <TextParagraph>[];

        final colSpan = int.tryParse(tc.getAttribute('gridSpan') ?? '') ?? 1;
        final rowSpan = int.tryParse(tc.getAttribute('rowSpan') ?? '') ?? 1;

        row.add(TableCell(
          paragraphs: paragraphs,
          fillColor: cellFill,
          borderColor: borderColor,
          borderWidth: borderW.clamp(0.5, 4.0),
          colSpan: colSpan,
          rowSpan: rowSpan,
        ));
      }
      rows.add(row);
    }

    return SlideElement(
      id: id,
      type: SlideElementType.table,
      x: xfrm['x']!,
      y: xfrm['y']!,
      width: xfrm['w']!.clamp(60, 9999),
      height: xfrm['h']!.clamp(20, 9999),
      tableRows: rows,
      tableColWidths: colWidths,
      tableRowHeights: rowHeights,
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Parse <p:cxnSp> — connector / line
  // ─────────────────────────────────────────────────────────────

  static SlideElement? _parseCxnSp(
    XmlElement cxn,
    int slideIndex,
    int zOrder,
    Map<String, Color> theme,
  ) {
    final id = 'sl${slideIndex}_cxn$zOrder';
    final xfrm = _parseXfrm(cxn.findAllElements('a:xfrm').firstOrNull);

    Color? strokeColor;
    double strokeWidth = 1.5;
    final spPr = cxn.findElements('p:spPr').firstOrNull;
    final ln = spPr?.findElements('a:ln').firstOrNull;
    if (ln != null) {
      strokeWidth = ((double.tryParse(ln.getAttribute('w') ?? '') ?? 19050) / _emuPerPx).clamp(0.5, 8.0);
      final solid = ln.findElements('a:solidFill').firstOrNull;
      if (solid != null) {
        strokeColor = _parseColorElement(solid.children.whereType<XmlElement>().firstOrNull, theme);
      }
    }

    // Very thin connectors can be invisible — ensure min height/width
    final w = xfrm['w']!.clamp(1.0, 9999.0);
    final h = xfrm['h']!.clamp(1.0, 9999.0);

    return SlideElement(
      id: id,
      type: SlideElementType.shape,
      shapeType: SlideShapeType.line,
      x: xfrm['x']!,
      y: xfrm['y']!,
      width: w,
      height: h,
      rotation: xfrm['rot']!,
      strokeColor: strokeColor ?? Colors.black54,
      strokeWidth: strokeWidth,
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Parse <p:grpSp> — group — flatten with group offset
  // ─────────────────────────────────────────────────────────────

  static List<SlideElement> _parseGrpSp(
    XmlElement grp,
    int slideIndex,
    int zOrder,
    Archive archive,
    Map<String, String> rIdToMedia,
    Map<String, Color> theme,
  ) {
    final grpXfrm = grp.findElements('p:grpSpPr')
        .firstOrNull
        ?.findAllElements('a:xfrm')
        .firstOrNull;

    final offX = _emu(grpXfrm?.findElements('a:off').firstOrNull?.getAttribute('x'));
    final offY = _emu(grpXfrm?.findElements('a:off').firstOrNull?.getAttribute('y'));

    final List<SlideElement> result = [];
    var childZ = 0;

    for (final child in grp.childElements) {
      final tag = child.name.local;
      SlideElement? elem;
      switch (tag) {
        case 'sp':
          elem = _parseShape(child, slideIndex, zOrder * 100 + childZ, theme);
          break;
        case 'pic':
          elem = _parsePic(child, slideIndex, zOrder * 100 + childZ, archive, rIdToMedia);
          break;
        case 'graphicFrame':
          elem = _parseGraphicFrame(child, slideIndex, zOrder * 100 + childZ, theme);
          break;
        case 'cxnSp':
          elem = _parseCxnSp(child, slideIndex, zOrder * 100 + childZ, theme);
          break;
      }
      if (elem != null) {
        // Apply group offset
        elem.x += offX;
        elem.y += offY;
        result.add(elem);
      }
      childZ++;
    }
    return result;
  }

  // ─────────────────────────────────────────────────────────────
  //  Parse text body → List<TextParagraph>
  // ─────────────────────────────────────────────────────────────

  static List<TextParagraph> _parseTxBody(XmlElement txBody, Map<String, Color> theme) {
    final paragraphs = <TextParagraph>[];

    // Default run properties from <a:lstStyle> or <a:bodyPr>
    Color defaultColor = Colors.black87;
    double defaultSize = 18.0;
    String? defaultFamily;

    final lstStyle = txBody.findElements('a:lstStyle').firstOrNull;
    if (lstStyle != null) {
      final defPPr = lstStyle.findAllElements('a:defPPr').firstOrNull;
      if (defPPr != null) {
        final defRPr = defPPr.findElements('a:defRPr').firstOrNull;
        if (defRPr != null) {
          defaultColor = _parseRPrColor(defRPr, theme) ?? defaultColor;
          defaultSize = _parseRPrSize(defRPr) ?? defaultSize;
          defaultFamily = _parseRPrFamily(defRPr);
        }
      }
    }

    for (final para in txBody.findElements('a:p')) {
      // Paragraph-level default run properties
      final pPr = para.findElements('a:pPr').firstOrNull;
      final defRPr = para.findElements('a:pPr').firstOrNull?.findElements('a:defRPr').firstOrNull;

      Color paraDefaultColor = _parseRPrColor(defRPr, theme) ?? defaultColor;
      double paraDefaultSize = _parseRPrSize(defRPr) ?? defaultSize;
      String? paraDefaultFamily = _parseRPrFamily(defRPr) ?? defaultFamily;

      TextAlign align = TextAlign.left;
      final algn = pPr?.getAttribute('algn');
      if (algn == 'ctr') {
        align = TextAlign.center;
      } else if (algn == 'r') {
        align = TextAlign.right;
      } else if (algn == 'just') {
        align = TextAlign.justify;
      }

      double spaceBefore = 0, spaceAfter = 0, lineSpacing = 1.0;
      final spcBef = pPr?.findElements('a:spcBef').firstOrNull;
      final spcSpc = spcBef?.findElements('a:spcPts').firstOrNull;
      if (spcSpc != null) {
        spaceBefore = (double.tryParse(spcSpc.getAttribute('val') ?? '') ?? 0) / 100.0;
      }
      final spcLin = pPr?.findElements('a:lnSpc').firstOrNull?.findElements('a:spcPct').firstOrNull;
      if (spcLin != null) {
        lineSpacing = (double.tryParse(spcLin.getAttribute('val') ?? '') ?? 100000) / 100000.0;
      }

      final runs = <TextRun>[];

      for (final child in para.childElements) {
        if (child.name.local == 'r') {
          // Regular run
          final rPr = child.findElements('a:rPr').firstOrNull;
          final text = child.findElements('a:t').firstOrNull?.innerText ?? '';

          final color = _parseRPrColor(rPr, theme) ?? paraDefaultColor;
          final size = _parseRPrSize(rPr) ?? paraDefaultSize;
          final family = _parseRPrFamily(rPr) ?? paraDefaultFamily;
          final bold = rPr?.getAttribute('b') == '1';
          final italic = rPr?.getAttribute('i') == '1';
          final underline = (rPr?.getAttribute('u') ?? '') != '' && rPr?.getAttribute('u') != 'none';
          final strike = rPr?.getAttribute('strike') != null && rPr?.getAttribute('strike') != 'noStrike';

          if (text.isNotEmpty) {
            runs.add(TextRun(
              text: text,
              fontSize: size.clamp(6.0, 120.0),
              isBold: bold,
              isItalic: italic,
              isUnderline: underline,
              isStrikethrough: strike,
              color: color,
              fontFamily: family,
            ));
          }
        } else if (child.name.local == 'br') {
          // Line break
          runs.add(TextRun(text: '\n', fontSize: paraDefaultSize, color: paraDefaultColor));
        } else if (child.name.local == 'fld') {
          // Field (slide number, date)
          final text = child.findElements('a:t').firstOrNull?.innerText ?? '';
          if (text.isNotEmpty) {
            runs.add(TextRun(text: text, fontSize: paraDefaultSize, color: paraDefaultColor));
          }
        }
      }

      // Even empty paragraphs add a newline spacer
      if (runs.isEmpty) {
        runs.add(TextRun(text: '', fontSize: paraDefaultSize, color: paraDefaultColor));
      }

      paragraphs.add(TextParagraph(
        runs: runs,
        align: align,
        spacingBefore: spaceBefore,
        spacingAfter: spaceAfter,
        lineSpacing: lineSpacing,
      ));
    }

    return paragraphs;
  }

  // ─────────────────────────────────────────────────────────────
  //  Color helpers
  // ─────────────────────────────────────────────────────────────

  static Color? _parseColorElement(XmlElement? el, Map<String, Color> theme) {
    if (el == null) return null;
    final tag = el.name.local;

    if (tag == 'srgbClr') {
      final hex = el.getAttribute('val') ?? '';
      return _hexToColor(hex);
    }

    if (tag == 'sysClr') {
      final lastClr = el.getAttribute('lastClr') ?? '';
      if (lastClr.isNotEmpty) return _hexToColor(lastClr);
    }

    if (tag == 'schemeClr') {
      final val = el.getAttribute('val') ?? '';
      final base = _schemeToKey(val);
      Color color = theme[base] ?? Colors.black;
      // Apply lum/shade/tint modifiers
      color = _applyColorMods(el, color);
      return color;
    }

    if (tag == 'prstClr') {
      return _presetColor(el.getAttribute('val') ?? '');
    }

    return null;
  }

  static Color? _parseRPrColor(XmlElement? rPr, Map<String, Color> theme) {
    if (rPr == null) return null;
    final solidFill = rPr.findElements('a:solidFill').firstOrNull;
    if (solidFill == null) return null;
    return _parseColorElement(solidFill.children.whereType<XmlElement>().firstOrNull, theme);
  }

  static double? _parseRPrSize(XmlElement? rPr) {
    if (rPr == null) return null;
    final sz = rPr.getAttribute('sz');
    if (sz == null) return null;
    return (double.tryParse(sz) ?? 1800) / 100.0;
  }

  static String? _parseRPrFamily(XmlElement? rPr) {
    if (rPr == null) return null;
    return rPr.findElements('a:latin').firstOrNull?.getAttribute('typeface');
  }

  static Color? _parseFillColor(XmlElement el, Map<String, Color> theme) {
    final solidFill = el.findElements('a:solidFill').firstOrNull;
    if (solidFill != null) {
      return _parseColorElement(solidFill.children.whereType<XmlElement>().firstOrNull, theme);
    }
    final noFill = el.findElements('a:noFill').firstOrNull;
    if (noFill != null) return null;
    return null;
  }

  static (List<Color>, double) _parseGradFill(XmlElement gradFill, Map<String, Color> theme) {
    final stops = gradFill.findAllElements('a:gs').map((gs) {
      final colorEl = gs.children.whereType<XmlElement>().firstOrNull;
      return _parseColorElement(colorEl, theme);
    }).whereType<Color>().toList();

    double angle = 0;
    final lin = gradFill.findElements('a:lin').firstOrNull;
    if (lin != null) {
      final angAttr = lin.getAttribute('ang') ?? '0';
      angle = (double.tryParse(angAttr) ?? 0) / 60000.0; // 60000ths of a degree
    }

    return (stops, angle);
  }

  static Color _applyColorMods(XmlElement schemeClrEl, Color base) {
    Color c = base;
    for (final mod in schemeClrEl.childElements) {
      final val = (double.tryParse(mod.getAttribute('val') ?? '') ?? 100000) / 100000.0;
      switch (mod.name.local) {
        case 'lumMod':
          c = _adjustLightness(c, val);
          break;
        case 'lumOff':
          c = _adjustLightness(c, 1.0 + val - 1.0);
          break;
        case 'shade':
          c = Color.fromARGB(
            (c.a * 255.0).round().clamp(0, 255),
            ((c.r * 255.0) * val).round().clamp(0, 255),
            ((c.g * 255.0) * val).round().clamp(0, 255),
            ((c.b * 255.0) * val).round().clamp(0, 255),
          );
          break;
        case 'tint':
          final inv = 1.0 - val;
          c = Color.fromARGB(
            (c.a * 255.0).round().clamp(0, 255),
            ((c.r * 255.0) + (255 - c.r * 255.0) * inv).round().clamp(0, 255),
            ((c.g * 255.0) + (255 - c.g * 255.0) * inv).round().clamp(0, 255),
            ((c.b * 255.0) + (255 - c.b * 255.0) * inv).round().clamp(0, 255),
          );
          break;
        case 'alpha':
          c = c.withValues(alpha: val.clamp(0.0, 1.0));
          break;
      }
    }
    return c;
  }

  static Color _adjustLightness(Color c, double factor) {
    return Color.fromARGB(
      (c.a * 255.0).round().clamp(0, 255),
      ((c.r * 255.0) * factor).round().clamp(0, 255),
      ((c.g * 255.0) * factor).round().clamp(0, 255),
      ((c.b * 255.0) * factor).round().clamp(0, 255),
    );
  }

  static String _schemeToKey(String val) {
    const map = {
      'dk1': 'dk1', 'lt1': 'lt1', 'dk2': 'dk2', 'lt2': 'lt2',
      'accent1': 'acc1', 'accent2': 'acc2', 'accent3': 'acc3',
      'accent4': 'acc4', 'accent5': 'acc5', 'accent6': 'acc6',
      'tx1': 'dk1', 'tx2': 'dk2', 'bg1': 'lt1', 'bg2': 'lt2',
      'hlink': 'acc1', 'folHlink': 'acc2',
    };
    return map[val] ?? val;
  }

  static Color _hexToColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    if (cleaned.length == 8) {
      return Color(int.parse(cleaned, radix: 16));
    }
    return Colors.black;
  }

  static Color _presetColor(String name) {
    const presets = {
      'white': Color(0xFFFFFFFF),
      'black': Color(0xFF000000),
      'red': Color(0xFFFF0000),
      'green': Color(0xFF008000),
      'blue': Color(0xFF0000FF),
      'yellow': Color(0xFFFFFF00),
      'cyan': Color(0xFF00FFFF),
      'magenta': Color(0xFFFF00FF),
      'orange': Color(0xFFFFA500),
      'purple': Color(0xFF800080),
      'gray': Color(0xFF808080),
      'grey': Color(0xFF808080),
      'silver': Color(0xFFC0C0C0),
      'navy': Color(0xFF000080),
      'teal': Color(0xFF008080),
      'maroon': Color(0xFF800000),
    };
    return presets[name.toLowerCase()] ?? Colors.black;
  }

  // ─────────────────────────────────────────────────────────────
  //  Shape geometry helpers
  // ─────────────────────────────────────────────────────────────

  static SlideShapeType _mapPreset(String prst) {
    switch (prst) {
      case 'ellipse':
        return SlideShapeType.circle;
      case 'roundRect':
        return SlideShapeType.roundedRectangle;
      case 'triangle':
      case 'rtTriangle':
        return SlideShapeType.triangle;
      case 'diamond':
        return SlideShapeType.diamond;
      case 'parallelogram':
        return SlideShapeType.parallelogram;
      case 'rightArrow':
      case 'leftArrow':
      case 'upArrow':
      case 'downArrow':
      case 'bentArrow':
      case 'uturnArrow':
        return SlideShapeType.arrow;
      case 'line':
      case 'straightConnector1':
        return SlideShapeType.line;
      default:
        return SlideShapeType.rectangle;
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Transform helpers
  // ─────────────────────────────────────────────────────────────

  static Map<String, double> _parseXfrm(XmlElement? xfrm) {
    if (xfrm == null) return {'x': 0, 'y': 0, 'w': 100, 'h': 50, 'rot': 0};
    final off = xfrm.findElements('a:off').firstOrNull;
    final ext = xfrm.findElements('a:ext').firstOrNull;
    final rotAttr = xfrm.getAttribute('rot') ?? '0';
    return {
      'x': _emu(off?.getAttribute('x')),
      'y': _emu(off?.getAttribute('y')),
      'w': _emu(ext?.getAttribute('cx')).clamp(1.0, 9999.0),
      'h': _emu(ext?.getAttribute('cy')).clamp(1.0, 9999.0),
      'rot': (double.tryParse(rotAttr) ?? 0) / 60000.0, // 60000ths of a degree
    };
  }

  static double _emu(String? val) {
    if (val == null) return 0;
    return (double.tryParse(val) ?? 0) / _emuPerPx;
  }

  // ─────────────────────────────────────────────────────────────
  //  Archive helpers
  // ─────────────────────────────────────────────────────────────

  static String? _archiveText(Archive archive, String path) {
    final f = archive.findFile(path);
    if (f == null) return null;
    try {
      return utf8.decode(f.content as List<int>);
    } catch (_) {
      return null;
    }
  }

  static Uint8List? _archiveBytes(Archive archive, String path) {
    final f = archive.findFile(path);
    if (f == null) return null;
    final content = f.content;
    if (content is Uint8List) return content;
    if (content is List<int>) return Uint8List.fromList(content);
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  //  PUBLIC: exportToPptx (write-back)
  // ─────────────────────────────────────────────────────────────

  static Uint8List exportToPptx(PresentationModel presentation) {
    final archive = Archive();

    // [Content_Types].xml
    final ctBuf = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..writeln('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">')
      ..writeln('  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>')
      ..writeln('  <Default Extension="xml" ContentType="application/xml"/>')
      ..writeln('  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>');
    for (var i = 1; i <= presentation.slides.length; i++) {
      ctBuf.writeln('  <Override PartName="/ppt/slides/slide$i.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>');
    }
    ctBuf.writeln('</Types>');
    _addToArchive(archive, '[Content_Types].xml', ctBuf.toString());

    // _rels/.rels
    const rootRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>'
        '</Relationships>';
    _addToArchive(archive, '_rels/.rels', rootRels);

    // ppt/presentation.xml
    final presBuf = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..writeln('<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">')
      ..writeln('  <p:sldIdLst>');
    for (var i = 1; i <= presentation.slides.length; i++) {
      presBuf.writeln('    <p:sldId id="${255 + i}" r:id="rId$i"/>');
    }
    presBuf
      ..writeln('  </p:sldIdLst>')
      ..writeln('</p:presentation>');
    _addToArchive(archive, 'ppt/presentation.xml', presBuf.toString());

    // ppt/_rels/presentation.xml.rels
    final presRelsBuf = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..writeln('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
    for (var i = 1; i <= presentation.slides.length; i++) {
      presRelsBuf.writeln('  <Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide$i.xml"/>');
    }
    presRelsBuf.writeln('</Relationships>');
    _addToArchive(archive, 'ppt/_rels/presentation.xml.rels', presRelsBuf.toString());

    // Individual slides
    for (var i = 0; i < presentation.slides.length; i++) {
      final slide = presentation.slides[i];
      final slideBuf = StringBuffer()
        ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
        ..writeln('<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">')
        ..writeln('  <p:cSld>')
        ..writeln('    <p:spTree>')
        ..writeln('      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:grpSpPr/></p:nvGrpSpPr>')
        ..writeln('      <p:grpSpPr/>');

      var spId = 2;
      for (final elem in slide.elements) {
        if (elem.type == SlideElementType.text || elem.type == SlideElementType.shape) {
          final escaped = (elem.content)
              .replaceAll('&', '&amp;')
              .replaceAll('<', '&lt;')
              .replaceAll('>', '&gt;');

          final x = (elem.x * _emuPerPx).toInt();
          final y = (elem.y * _emuPerPx).toInt();
          final cx = (elem.width * _emuPerPx).toInt();
          final cy = (elem.height * _emuPerPx).toInt();

          slideBuf
            ..writeln('      <p:sp>')
            ..writeln('        <p:nvSpPr><p:cNvPr id="$spId" name="Sp $spId"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>')
            ..writeln('        <p:spPr><a:xfrm><a:off x="$x" y="$y"/><a:ext cx="$cx" cy="$cy"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>')
            ..writeln('        <p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr sz="${(elem.fontSize * 100).toInt()}" b="${elem.isBold ? 1 : 0}" i="${elem.isItalic ? 1 : 0}"/><a:t>$escaped</a:t></a:r></a:p></p:txBody>')
            ..writeln('      </p:sp>');
          spId++;
        }
      }

      slideBuf
        ..writeln('    </p:spTree>')
        ..writeln('  </p:cSld>')
        ..writeln('</p:sld>');
      _addToArchive(archive, 'ppt/slides/slide${i + 1}.xml', slideBuf.toString());
    }

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded ?? []);
  }

  static void _addToArchive(Archive archive, String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }
}
