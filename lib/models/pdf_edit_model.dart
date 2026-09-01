import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

enum PdfElementType {
  text,
  image,
  whiteout,
}

class PdfElement {
  String id;
  int pageNumber;
  PdfElementType type;
  double x;
  double y;
  double width;
  double height;

  // Text specific properties
  String text;
  double fontSize;
  Color textColor;
  Color? backgroundColor; // e.g. opaque white to mask original PDF text
  bool isBold;
  bool isItalic;
  TextAlign textAlign;

  // Image specific properties
  String? imagePath;
  Uint8List? imageBytes;

  // Whiteout specific properties
  Color whiteoutColor;

  PdfElement({
    required this.id,
    required this.pageNumber,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.text = '',
    this.fontSize = 14.0,
    this.textColor = Colors.black,
    this.backgroundColor,
    this.isBold = false,
    this.isItalic = false,
    this.textAlign = TextAlign.left,
    this.imagePath,
    this.imageBytes,
    this.whiteoutColor = Colors.white,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pageNumber': pageNumber,
      'type': type.name,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'text': text,
      'fontSize': fontSize,
      'textColor': textColor.toARGB32(),
      'backgroundColor': backgroundColor?.toARGB32(),
      'isBold': isBold,
      'isItalic': isItalic,
      'textAlign': textAlign.name,
      'imagePath': imagePath,
      'imageBytes': imageBytes != null ? base64Encode(imageBytes!) : null,
      'whiteoutColor': whiteoutColor.toARGB32(),
    };
  }

  factory PdfElement.fromMap(Map<String, dynamic> map) {
    return PdfElement(
      id: map['id'] as String,
      pageNumber: map['pageNumber'] as int,
      type: PdfElementType.values.firstWhere((e) => e.name == map['type']),
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      width: (map['width'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
      text: map['text'] as String? ?? '',
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 14.0,
      textColor: Color(map['textColor'] as int? ?? 0xFF000000),
      backgroundColor: map['backgroundColor'] != null ? Color(map['backgroundColor'] as int) : null,
      isBold: map['isBold'] as bool? ?? false,
      isItalic: map['isItalic'] as bool? ?? false,
      textAlign: TextAlign.values.firstWhere(
        (e) => e.name == map['textAlign'],
        orElse: () => TextAlign.left,
      ),
      imagePath: map['imagePath'] as String?,
      imageBytes: map['imageBytes'] != null ? base64Decode(map['imageBytes'] as String) : null,
      whiteoutColor: Color(map['whiteoutColor'] as int? ?? 0xFFFFFFFF),
    );
  }
}
