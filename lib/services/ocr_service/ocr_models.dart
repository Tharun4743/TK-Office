import 'package:flutter/material.dart';

/// Represents a single recognized word with bounding box and confidence
class OCRWord {
  final String text;
  final Rect boundingBox;
  final double confidence;

  OCRWord({
    required this.text,
    required this.boundingBox,
    required this.confidence,
  });
}

/// Represents a recognized text line composed of words
class OCRLine {
  final String text;
  final Rect boundingBox;
  final double confidence;
  final List<OCRWord> words;

  OCRLine({
    required this.text,
    required this.boundingBox,
    required this.confidence,
    this.words = const [],
  });
}

/// Represents a recognized block or paragraph of text in a scanned PDF page
class OCRTextBlock {
  final String id;
  String text;
  final int pageIndex;
  Rect boundingBox;
  final double confidence;
  final List<OCRLine> lines;

  // Font and style estimates for visual matching
  double fontSize;
  String fontFamilyEstimate;
  FontWeight fontWeight;
  bool isItalic;
  Color textColor;
  TextAlign alignment;
  Color sampledBackgroundColor;

  OCRTextBlock({
    required this.id,
    required this.text,
    required this.pageIndex,
    required this.boundingBox,
    required this.confidence,
    this.lines = const [],
    this.fontSize = 14.0,
    this.fontFamilyEstimate = 'Roboto',
    this.fontWeight = FontWeight.normal,
    this.isItalic = false,
    this.textColor = Colors.black87,
    this.alignment = TextAlign.left,
    this.sampledBackgroundColor = Colors.white,
  });

  OCRTextBlock copyWith({
    String? text,
    Rect? boundingBox,
    double? fontSize,
    String? fontFamilyEstimate,
    FontWeight? fontWeight,
    bool? isItalic,
    Color? textColor,
    TextAlign? alignment,
    Color? sampledBackgroundColor,
  }) {
    return OCRTextBlock(
      id: id,
      text: text ?? this.text,
      pageIndex: pageIndex,
      boundingBox: boundingBox ?? this.boundingBox,
      confidence: confidence,
      lines: lines,
      fontSize: fontSize ?? this.fontSize,
      fontFamilyEstimate: fontFamilyEstimate ?? this.fontFamilyEstimate,
      fontWeight: fontWeight ?? this.fontWeight,
      isItalic: isItalic ?? this.isItalic,
      textColor: textColor ?? this.textColor,
      alignment: alignment ?? this.alignment,
      sampledBackgroundColor: sampledBackgroundColor ?? this.sampledBackgroundColor,
    );
  }
}

/// Represents an entire analyzed scanned PDF page
class OCRPage {
  final int pageIndex;
  final double pageWidth;
  final double pageHeight;
  final List<OCRTextBlock> blocks;
  final bool isScannedImage;

  OCRPage({
    required this.pageIndex,
    required this.pageWidth,
    required this.pageHeight,
    required this.blocks,
    required this.isScannedImage,
  });
}

/// Supported PDF page types
enum PdfPageType {
  nativeText,  // Type A: Selectable vector text
  scannedImage,// Type B: Pure raster image
  mixed,       // Type C: Both vector text and images
}
