import 'package:flutter/material.dart';

enum AnnotationType {
  freehand,
  highlight,
  text,
  rectangle,
}

class DrawingPoint {
  final Offset offset;
  final Paint paint;

  DrawingPoint({
    required this.offset,
    required this.paint,
  });
}

class PdfAnnotation {
  final String id;
  final int pageNumber;
  final AnnotationType type;
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final String text;

  PdfAnnotation({
    required this.id,
    required this.pageNumber,
    required this.type,
    required this.points,
    this.color = Colors.yellow,
    this.strokeWidth = 3.0,
    this.text = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pageNumber': pageNumber,
      'type': type.name,
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'color': color.toARGB32(),
      'strokeWidth': strokeWidth,
      'text': text,
    };
  }

  factory PdfAnnotation.fromMap(Map<String, dynamic> map) {
    return PdfAnnotation(
      id: map['id'] as String,
      pageNumber: map['pageNumber'] as int,
      type: AnnotationType.values.firstWhere((e) => e.name == map['type']),
      points: (map['points'] as List<dynamic>)
          .map((p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()))
          .toList(),
      color: Color(map['color'] as int? ?? 0xFFFFEB3B),
      strokeWidth: (map['strokeWidth'] as num?)?.toDouble() ?? 3.0,
      text: map['text'] as String? ?? '',
    );
  }
}
