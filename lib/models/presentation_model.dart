import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  Element types
// ─────────────────────────────────────────────────────────────

enum SlideElementType {
  text,
  shape,
  image,
  table,
  fallback, // charts, SmartArt, unsupported → styled placeholder
}

enum SlideShapeType {
  rectangle,
  roundedRectangle,
  circle,
  arrow,
  line,
  triangle,
  diamond,
  parallelogram,
}

// ─────────────────────────────────────────────────────────────
//  Rich text run — a single styled span inside a text element
// ─────────────────────────────────────────────────────────────

class TextRun {
  final String text;
  final double fontSize;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final bool isStrikethrough;
  final Color color;
  final String? fontFamily;
  final double? letterSpacing;

  const TextRun({
    required this.text,
    this.fontSize = 18.0,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikethrough = false,
    this.color = Colors.black87,
    this.fontFamily,
    this.letterSpacing,
  });

  Map<String, dynamic> toMap() => {
        'text': text,
        'font_size': fontSize,
        'is_bold': isBold,
        'is_italic': isItalic,
        'is_underline': isUnderline,
        'is_strikethrough': isStrikethrough,
        'color': color.toARGB32(),
        'font_family': fontFamily,
        'letter_spacing': letterSpacing,
      };

  factory TextRun.fromMap(Map<String, dynamic> m) => TextRun(
        text: m['text'] as String? ?? '',
        fontSize: (m['font_size'] as num?)?.toDouble() ?? 18.0,
        isBold: m['is_bold'] as bool? ?? false,
        isItalic: m['is_italic'] as bool? ?? false,
        isUnderline: m['is_underline'] as bool? ?? false,
        isStrikethrough: m['is_strikethrough'] as bool? ?? false,
        color: Color(m['color'] as int? ?? 0xFF000000),
        fontFamily: m['font_family'] as String?,
        letterSpacing: (m['letter_spacing'] as num?)?.toDouble(),
      );

  /// Build a TextSpan for rich rendering
  TextSpan toSpan() => TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          decoration: textDecoration,
          color: color,
          fontFamily: fontFamily,
          letterSpacing: letterSpacing,
        ),
      );

  TextDecoration get textDecoration {
    if (isUnderline && isStrikethrough) {
      return TextDecoration.combine([TextDecoration.underline, TextDecoration.lineThrough]);
    } else if (isUnderline) {
      return TextDecoration.underline;
    } else if (isStrikethrough) {
      return TextDecoration.lineThrough;
    }
    return TextDecoration.none;
  }
}

// ─────────────────────────────────────────────────────────────
//  Paragraph — a list of runs with shared paragraph alignment
// ─────────────────────────────────────────────────────────────

class TextParagraph {
  final List<TextRun> runs;
  final TextAlign align;
  final double spacingBefore; // pts
  final double spacingAfter;  // pts
  final double lineSpacing;   // multiplier, 1.0 = single

  const TextParagraph({
    required this.runs,
    this.align = TextAlign.left,
    this.spacingBefore = 0,
    this.spacingAfter = 0,
    this.lineSpacing = 1.0,
  });

  Map<String, dynamic> toMap() => {
        'runs': runs.map((r) => r.toMap()).toList(),
        'align': align.name,
        'spacing_before': spacingBefore,
        'spacing_after': spacingAfter,
        'line_spacing': lineSpacing,
      };

  factory TextParagraph.fromMap(Map<String, dynamic> m) => TextParagraph(
        runs: (m['runs'] as List<dynamic>?)
                ?.map((r) => TextRun.fromMap(r as Map<String, dynamic>))
                .toList() ??
            [],
        align: TextAlign.values.firstWhere(
          (e) => e.name == m['align'],
          orElse: () => TextAlign.left,
        ),
        spacingBefore: (m['spacing_before'] as num?)?.toDouble() ?? 0,
        spacingAfter: (m['spacing_after'] as num?)?.toDouble() ?? 0,
        lineSpacing: (m['line_spacing'] as num?)?.toDouble() ?? 1.0,
      );

  /// Plain text of all runs joined
  String get plainText => runs.map((r) => r.text).join();
}

// ─────────────────────────────────────────────────────────────
//  Table cell
// ─────────────────────────────────────────────────────────────

class TableCell {
  final List<TextParagraph> paragraphs;
  final Color? fillColor;
  final Color borderColor;
  final double borderWidth;
  final int colSpan;
  final int rowSpan;

  const TableCell({
    this.paragraphs = const [],
    this.fillColor,
    this.borderColor = Colors.black38,
    this.borderWidth = 1.0,
    this.colSpan = 1,
    this.rowSpan = 1,
  });

  Map<String, dynamic> toMap() => {
        'paragraphs': paragraphs.map((p) => p.toMap()).toList(),
        'fill_color': fillColor?.toARGB32(),
        'border_color': borderColor.toARGB32(),
        'border_width': borderWidth,
        'col_span': colSpan,
        'row_span': rowSpan,
      };

  factory TableCell.fromMap(Map<String, dynamic> m) => TableCell(
        paragraphs: (m['paragraphs'] as List<dynamic>?)
                ?.map((p) => TextParagraph.fromMap(p as Map<String, dynamic>))
                .toList() ??
            [],
        fillColor: m['fill_color'] != null ? Color(m['fill_color'] as int) : null,
        borderColor: Color(m['border_color'] as int? ?? 0x61000000),
        borderWidth: (m['border_width'] as num?)?.toDouble() ?? 1.0,
        colSpan: m['col_span'] as int? ?? 1,
        rowSpan: m['row_span'] as int? ?? 1,
      );
}

// ─────────────────────────────────────────────────────────────
//  SlideElement — one object on the slide
// ─────────────────────────────────────────────────────────────

class SlideElement {
  String id;
  SlideElementType type;

  // Position & size (logical pixels, converted from EMU /12700)
  double x;
  double y;
  double width;
  double height;
  double rotation; // degrees

  // ── Legacy plain-text content (used by the built-in editor)
  String content;
  double fontSize;
  bool isBold;
  bool isItalic;
  Color textColor;
  TextAlign align;

  // ── Rich text (paragraphs) — parsed from PPTX; overrides plain content
  List<TextParagraph> paragraphs;

  // ── Shape
  SlideShapeType shapeType;
  Color? fillColor;
  Color? strokeColor;
  double strokeWidth;

  // ── Image
  Uint8List? imageBytes;

  // ── Table (rows × cols)
  List<List<TableCell>> tableRows;
  List<double> tableColWidths;
  List<double> tableRowHeights;

  // ── Visual
  double opacity; // 0.0–1.0

  // ── Fallback label (charts, SmartArt, unsupported)
  String fallbackLabel;

  SlideElement({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0.0,
    this.content = '',
    this.shapeType = SlideShapeType.rectangle,
    this.fontSize = 18.0,
    this.isBold = false,
    this.isItalic = false,
    this.textColor = Colors.black87,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 0.0,
    this.align = TextAlign.left,
    this.paragraphs = const [],
    this.imageBytes,
    this.tableRows = const [],
    this.tableColWidths = const [],
    this.tableRowHeights = const [],
    this.opacity = 1.0,
    this.fallbackLabel = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotation': rotation,
      'content': content,
      'shape_type': shapeType.name,
      'font_size': fontSize,
      'is_bold': isBold,
      'is_italic': isItalic,
      'text_color': textColor.toARGB32(),
      'fill_color': fillColor?.toARGB32(),
      'stroke_color': strokeColor?.toARGB32(),
      'stroke_width': strokeWidth,
      'align': align.name,
      'paragraphs': paragraphs.map((p) => p.toMap()).toList(),
      'image_bytes': imageBytes != null ? base64Encode(imageBytes!) : null,
      'table_rows': tableRows
          .map((row) => row.map((cell) => cell.toMap()).toList())
          .toList(),
      'table_col_widths': tableColWidths,
      'table_row_heights': tableRowHeights,
      'opacity': opacity,
      'fallback_label': fallbackLabel,
    };
  }

  factory SlideElement.fromMap(Map<String, dynamic> map) {
    return SlideElement(
      id: map['id'] as String,
      type: SlideElementType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => SlideElementType.text,
      ),
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      width: (map['width'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
      rotation: (map['rotation'] as num?)?.toDouble() ?? 0.0,
      content: map['content'] as String? ?? '',
      shapeType: SlideShapeType.values.firstWhere(
        (e) => e.name == map['shape_type'],
        orElse: () => SlideShapeType.rectangle,
      ),
      fontSize: (map['font_size'] as num?)?.toDouble() ?? 18.0,
      isBold: map['is_bold'] as bool? ?? false,
      isItalic: map['is_italic'] as bool? ?? false,
      textColor: Color(map['text_color'] as int? ?? 0xFF000000),
      fillColor: map['fill_color'] != null ? Color(map['fill_color'] as int) : null,
      strokeColor: map['stroke_color'] != null ? Color(map['stroke_color'] as int) : null,
      strokeWidth: (map['stroke_width'] as num?)?.toDouble() ?? 0.0,
      align: TextAlign.values.firstWhere(
        (e) => e.name == map['align'],
        orElse: () => TextAlign.left,
      ),
      paragraphs: (map['paragraphs'] as List<dynamic>?)
              ?.map((p) => TextParagraph.fromMap(p as Map<String, dynamic>))
              .toList() ??
          [],
      imageBytes: map['image_bytes'] != null
          ? base64Decode(map['image_bytes'] as String)
          : null,
      tableRows: (map['table_rows'] as List<dynamic>?)
              ?.map((row) => (row as List<dynamic>)
                  .map((cell) => TableCell.fromMap(cell as Map<String, dynamic>))
                  .toList())
              .toList() ??
          [],
      tableColWidths: (map['table_col_widths'] as List<dynamic>?)
              ?.map((v) => (v as num).toDouble())
              .toList() ??
          [],
      tableRowHeights: (map['table_row_heights'] as List<dynamic>?)
              ?.map((v) => (v as num).toDouble())
              .toList() ??
          [],
      opacity: (map['opacity'] as num?)?.toDouble() ?? 1.0,
      fallbackLabel: map['fallback_label'] as String? ?? '',
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SlideModel — one slide
// ─────────────────────────────────────────────────────────────

class SlideModel {
  String id;
  String title;

  // Background
  Color backgroundColor;
  List<Color> backgroundGradientColors; // empty = no gradient
  double backgroundGradientAngle;       // degrees
  Uint8List? backgroundImageBytes;

  // Logical slide dimensions (converted from EMU /12700)
  // Standard 16:9 PPTX = 9144000 × 5143500 EMU → 720 × 405 px
  double slideWidth;
  double slideHeight;

  List<SlideElement> elements;
  String speakerNotes;

  SlideModel({
    required this.id,
    required this.title,
    this.backgroundColor = Colors.white,
    this.backgroundGradientColors = const [],
    this.backgroundGradientAngle = 0.0,
    this.backgroundImageBytes,
    this.slideWidth = 720.0,
    this.slideHeight = 405.0,
    List<SlideElement>? elements,
    this.speakerNotes = '',
  }) : elements = elements ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'bg_color': backgroundColor.toARGB32(),
      'bg_gradient_colors': backgroundGradientColors.map((c) => c.toARGB32()).toList(),
      'bg_gradient_angle': backgroundGradientAngle,
      'bg_image_bytes': backgroundImageBytes != null ? base64Encode(backgroundImageBytes!) : null,
      'slide_width': slideWidth,
      'slide_height': slideHeight,
      'speaker_notes': speakerNotes,
      'elements': elements.map((e) => e.toMap()).toList(),
    };
  }

  factory SlideModel.fromMap(Map<String, dynamic> map) {
    return SlideModel(
      id: map['id'] as String,
      title: map['title'] as String,
      backgroundColor: Color(map['bg_color'] as int? ?? 0xFFFFFFFF),
      backgroundGradientColors: (map['bg_gradient_colors'] as List<dynamic>?)
              ?.map((v) => Color(v as int))
              .toList() ??
          [],
      backgroundGradientAngle: (map['bg_gradient_angle'] as num?)?.toDouble() ?? 0.0,
      backgroundImageBytes: map['bg_image_bytes'] != null
          ? base64Decode(map['bg_image_bytes'] as String)
          : null,
      slideWidth: (map['slide_width'] as num?)?.toDouble() ?? 720.0,
      slideHeight: (map['slide_height'] as num?)?.toDouble() ?? 405.0,
      speakerNotes: map['speaker_notes'] as String? ?? '',
      elements: (map['elements'] as List<dynamic>?)
              ?.map((e) => SlideElement.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  factory SlideModel.titleSlide({
    required String id,
    String title = 'Presentation Title',
    String subtitle = 'Subtitle',
  }) {
    return SlideModel(
      id: id,
      title: title,
      elements: [
        SlideElement(
          id: '${id}_title',
          type: SlideElementType.text,
          x: 40,
          y: 100,
          width: 640,
          height: 80,
          content: title,
          fontSize: 32,
          isBold: true,
          align: TextAlign.center,
          paragraphs: [
            TextParagraph(
              runs: [TextRun(text: title, fontSize: 32, isBold: true, color: Colors.black87)],
              align: TextAlign.center,
            ),
          ],
        ),
        SlideElement(
          id: '${id}_subtitle',
          type: SlideElementType.text,
          x: 40,
          y: 200,
          width: 640,
          height: 50,
          content: subtitle,
          fontSize: 20,
          textColor: Colors.grey.shade700,
          align: TextAlign.center,
          paragraphs: [
            TextParagraph(
              runs: [TextRun(text: subtitle, fontSize: 20, color: Colors.grey.shade700)],
              align: TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  PresentationModel
// ─────────────────────────────────────────────────────────────

class PresentationModel {
  String? filePath;
  String title;
  List<SlideModel> slides;
  int activeSlideIndex;
  DateTime lastModified;
  bool isDirty;

  PresentationModel({
    this.filePath,
    required this.title,
    required this.slides,
    this.activeSlideIndex = 0,
    required this.lastModified,
    this.isDirty = false,
  });

  SlideModel get activeSlide => slides[activeSlideIndex];

  factory PresentationModel.empty({String title = 'Untitled Presentation'}) {
    return PresentationModel(
      title: title,
      slides: [
        SlideModel.titleSlide(id: 'slide_1', title: title),
      ],
      lastModified: DateTime.now(),
      isDirty: false,
    );
  }

  String toJsonString() {
    final map = {
      'title': title,
      'slides': slides.map((s) => s.toMap()).toList(),
    };
    return jsonEncode(map);
  }

  factory PresentationModel.fromJsonString(String jsonString, {String? filePath}) {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    final title = map['title'] as String? ?? 'Presentation';
    final slidesList = (map['slides'] as List<dynamic>)
        .map((s) => SlideModel.fromMap(s as Map<String, dynamic>))
        .toList();

    return PresentationModel(
      filePath: filePath,
      title: title,
      slides: slidesList.isNotEmpty ? slidesList : [SlideModel.titleSlide(id: 'slide_1')],
      lastModified: DateTime.now(),
    );
  }
}
