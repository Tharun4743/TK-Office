import 'dart:convert';
import 'package:flutter/material.dart';

enum SlideElementType {
  text,
  shape,
  image,
}

enum SlideShapeType {
  rectangle,
  roundedRectangle,
  circle,
  arrow,
}

class SlideElement {
  String id;
  SlideElementType type;
  double x;
  double y;
  double width;
  double height;
  String content; // text content, image path, or shape label
  SlideShapeType shapeType;
  double fontSize;
  bool isBold;
  bool isItalic;
  Color textColor;
  Color? fillColor;
  TextAlign align;

  SlideElement({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.content = '',
    this.shapeType = SlideShapeType.rectangle,
    this.fontSize = 18.0,
    this.isBold = false,
    this.isItalic = false,
    this.textColor = Colors.black87,
    this.fillColor,
    this.align = TextAlign.left,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'content': content,
      'shape_type': shapeType.name,
      'font_size': fontSize,
      'is_bold': isBold,
      'is_italic': isItalic,
      'text_color': textColor.toARGB32(),
      'fill_color': fillColor?.toARGB32(),
      'align': align.name,
    };
  }

  factory SlideElement.fromMap(Map<String, dynamic> map) {
    return SlideElement(
      id: map['id'] as String,
      type: SlideElementType.values.firstWhere((e) => e.name == map['type']),
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      width: (map['width'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
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
      align: TextAlign.values.firstWhere(
        (e) => e.name == map['align'],
        orElse: () => TextAlign.left,
      ),
    );
  }
}

class SlideModel {
  String id;
  String title;
  Color backgroundColor;
  List<SlideElement> elements;
  String speakerNotes;

  SlideModel({
    required this.id,
    required this.title,
    this.backgroundColor = Colors.white,
    List<SlideElement>? elements,
    this.speakerNotes = '',
  }) : elements = elements ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'bg_color': backgroundColor.toARGB32(),
      'speaker_notes': speakerNotes,
      'elements': elements.map((e) => e.toMap()).toList(),
    };
  }

  factory SlideModel.fromMap(Map<String, dynamic> map) {
    return SlideModel(
      id: map['id'] as String,
      title: map['title'] as String,
      backgroundColor: Color(map['bg_color'] as int? ?? 0xFFFFFFFF),
      speakerNotes: map['speaker_notes'] as String? ?? '',
      elements: (map['elements'] as List<dynamic>?)
              ?.map((e) => SlideElement.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  factory SlideModel.titleSlide({required String id, String title = 'Presentation Title', String subtitle = 'Subtitle'}) {
    return SlideModel(
      id: id,
      title: title,
      elements: [
        SlideElement(
          id: '${id}_title',
          type: SlideElementType.text,
          x: 40,
          y: 60,
          width: 320,
          height: 60,
          content: title,
          fontSize: 26,
          isBold: true,
          align: TextAlign.center,
        ),
        SlideElement(
          id: '${id}_subtitle',
          type: SlideElementType.text,
          x: 40,
          y: 130,
          width: 320,
          height: 40,
          content: subtitle,
          fontSize: 16,
          textColor: Colors.grey.shade700,
          align: TextAlign.center,
        ),
      ],
    );
  }
}

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
