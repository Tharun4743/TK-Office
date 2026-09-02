import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/presentation_model.dart';
import '../../shared/widgets/tk_dialogs.dart';
import 'slides_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SlideCanvas
//  Renders the active slide with full visual fidelity:
//    • Slide background (solid color / gradient / image)
//    • Text elements with rich paragraphs (font, color, size, bold, italic,
//      underline, strikethrough, alignment, line spacing)
//    • Shapes (rect, rounded rect, circle, triangle, diamond, arrow, line)
//      with fill color and stroke
//    • Images (from embedded bytes)
//    • Tables (with cell fills and borders)
//    • Fallback placeholders for charts / SmartArt
//    • Interactive drag-to-move and double-tap-to-edit for text boxes
// ─────────────────────────────────────────────────────────────────────────────

class SlideCanvas extends StatelessWidget {
  final SlidesController controller;

  const SlideCanvas({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final slide = controller.activeSlide;

    if (slide == null) {
      return const Center(child: Text('No slide selected'));
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        // The slide is always 16:9; LayoutBuilder gives us the actual pixels
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              // Scale factor: logical slide coordinates → canvas pixels
              final scale = constraints.maxWidth / slide.slideWidth;

              return GestureDetector(
                onTap: () => controller.selectElement(null),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 60 : 20),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Stack(
                      children: [
                        // ── 1. Slide Background ──────────────────────────
                        Positioned.fill(child: _buildBackground(slide)),

                        // ── 2. Slide Elements (scaled) ───────────────────
                        ...slide.elements.map((elem) =>
                            _buildPositionedElement(ctx, elem, scale)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Background
  // ─────────────────────────────────────────────────────────────

  Widget _buildBackground(SlideModel slide) {
    // Background image takes priority
    if (slide.backgroundImageBytes != null) {
      return Image.memory(
        slide.backgroundImageBytes!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _solidBackground(slide.backgroundColor),
      );
    }

    // Gradient
    if (slide.backgroundGradientColors.length >= 2) {
      final angle = slide.backgroundGradientAngle * math.pi / 180.0;
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: slide.backgroundGradientColors,
            begin: Alignment(
              -math.cos(angle + math.pi / 2),
              -math.sin(angle + math.pi / 2),
            ),
            end: Alignment(
              math.cos(angle + math.pi / 2),
              math.sin(angle + math.pi / 2),
            ),
          ),
        ),
      );
    }

    return _solidBackground(slide.backgroundColor);
  }

  Widget _solidBackground(Color color) => Container(color: color);

  // ─────────────────────────────────────────────────────────────
  //  Positioned element wrapper (handles scale, rotation, opacity)
  // ─────────────────────────────────────────────────────────────

  Widget _buildPositionedElement(
    BuildContext context,
    SlideElement elem,
    double scale,
  ) {
    final isSelected = elem.id == controller.selectedElementId;

    Widget inner = _buildElementWidget(context, elem, scale, isSelected);

    // Apply opacity
    if (elem.opacity < 0.999) {
      inner = Opacity(opacity: elem.opacity.clamp(0.0, 1.0), child: inner);
    }

    // Apply rotation
    if (elem.rotation.abs() > 0.01) {
      inner = Transform.rotate(
        angle: elem.rotation * math.pi / 180.0,
        child: inner,
      );
    }

    // Selection ring (outside the element so it doesn't clip)
    if (isSelected) {
      inner = Stack(
        children: [
          inner,
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.slideOrange, width: 2),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Positioned(
      left: elem.x * scale,
      top: elem.y * scale,
      child: GestureDetector(
        onTap: () => controller.selectElement(elem.id),
        onDoubleTap: () async {
          if (elem.type == SlideElementType.text) {
            final newText = await TKDialogs.showNameInputDialog(
              context: context,
              title: 'Edit Text Box',
              initialValue: elem.content,
              actionLabel: 'Update',
            );
            if (newText != null) {
              controller.updateElementText(elem.id, newText);
            }
          }
        },
        onPanUpdate: (details) {
          controller.updateElementPosition(
            elem.id,
            elem.x + details.delta.dx / scale,
            elem.y + details.delta.dy / scale,
          );
        },
        child: SizedBox(
          width: elem.width * scale,
          height: elem.height * scale,
          child: inner,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Element type dispatcher
  // ─────────────────────────────────────────────────────────────

  Widget _buildElementWidget(
    BuildContext context,
    SlideElement elem,
    double scale,
    bool isSelected,
  ) {
    switch (elem.type) {
      case SlideElementType.text:
        return _buildTextElement(elem, scale);
      case SlideElementType.shape:
        return _buildShapeElement(elem, scale);
      case SlideElementType.image:
        return _buildImageElement(elem);
      case SlideElementType.table:
        return _buildTableElement(elem, scale);
      case SlideElementType.fallback:
        return _buildFallbackElement(elem, scale);
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Text element — rich paragraphs with TextSpan
  // ─────────────────────────────────────────────────────────────

  Widget _buildTextElement(SlideElement elem, double scale) {
    Widget content;

    if (elem.paragraphs.isNotEmpty &&
        elem.paragraphs.any((p) => p.runs.any((r) => r.text.isNotEmpty))) {
      // Rich text with multiple paragraphs
      content = _buildRichText(elem, scale);
    } else {
      // Legacy plain text (for user-created elements)
      content = Text(
        elem.content,
        style: TextStyle(
          fontSize: elem.fontSize * scale,
          fontWeight: elem.isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: elem.isItalic ? FontStyle.italic : FontStyle.normal,
          color: elem.textColor,
        ),
        textAlign: elem.align,
        overflow: TextOverflow.clip,
      );
    }

    // Text boxes have no background fill (transparent by default)
    return Container(
      color: elem.fillColor,
      padding: const EdgeInsets.all(2),
      child: content,
    );
  }

  Widget _buildRichText(SlideElement elem, double scale) {
    if (elem.paragraphs.length == 1) {
      final para = elem.paragraphs.first;
      return RichText(
        text: TextSpan(children: _buildParagraphSpans(para, scale)),
        textAlign: para.align,
        overflow: TextOverflow.clip,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: elem.paragraphs.map((para) {
        return Padding(
          padding: EdgeInsets.only(
            top: (para.spacingBefore * scale).clamp(0.0, 40.0),
            bottom: (para.spacingAfter * scale).clamp(0.0, 40.0),
          ),
          child: RichText(
            text: TextSpan(children: _buildParagraphSpans(para, scale)),
            textAlign: para.align,
            overflow: TextOverflow.clip,
          ),
        );
      }).toList(),
    );
  }

  List<InlineSpan> _buildParagraphSpans(TextParagraph para, double scale) {
    return para.runs.map((run) {
      return TextSpan(
        text: run.text,
        style: TextStyle(
          fontSize: (run.fontSize * scale).clamp(4.0, 200.0),
          fontWeight: run.isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: run.isItalic ? FontStyle.italic : FontStyle.normal,
          decoration: run.textDecoration,
          color: run.color,
          fontFamily: run.fontFamily,
          letterSpacing: run.letterSpacing != null ? run.letterSpacing! * scale : null,
          height: para.lineSpacing > 0 ? para.lineSpacing : null,
        ),
      );
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────
  //  Shape element — uses CustomPaint for triangles/diamonds/lines
  // ─────────────────────────────────────────────────────────────

  Widget _buildShapeElement(SlideElement elem, double scale) {
    final fill = elem.fillColor ?? AppTheme.slideOrange.withAlpha(50);
    final stroke = elem.strokeColor;
    final strokeW = (elem.strokeWidth * scale).clamp(0.0, 8.0);

    Widget shapeBody;
    switch (elem.shapeType) {
      case SlideShapeType.circle:
        shapeBody = _paintedShape(
          fill: fill,
          stroke: stroke,
          strokeW: strokeW,
          painter: _CirclePainter(fill: fill, stroke: stroke, strokeW: strokeW),
        );
        break;

      case SlideShapeType.triangle:
        shapeBody = _paintedShape(
          fill: fill,
          stroke: stroke,
          strokeW: strokeW,
          painter: _TrianglePainter(fill: fill, stroke: stroke, strokeW: strokeW),
        );
        break;

      case SlideShapeType.diamond:
        shapeBody = _paintedShape(
          fill: fill,
          stroke: stroke,
          strokeW: strokeW,
          painter: _DiamondPainter(fill: fill, stroke: stroke, strokeW: strokeW),
        );
        break;

      case SlideShapeType.line:
        shapeBody = _paintedShape(
          fill: Colors.transparent,
          stroke: stroke ?? Colors.black54,
          strokeW: strokeW > 0 ? strokeW : 1.5,
          painter: _LinePainter(color: stroke ?? Colors.black54, strokeW: strokeW > 0 ? strokeW : 1.5),
        );
        break;

      case SlideShapeType.arrow:
        shapeBody = Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            border: stroke != null
                ? Border.all(color: stroke, width: strokeW)
                : null,
          ),
          child: Icon(Icons.arrow_forward_rounded, color: stroke ?? Colors.black54, size: 20 * scale),
        );
        break;

      case SlideShapeType.roundedRectangle:
        shapeBody = Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(8 * scale),
            border: stroke != null
                ? Border.all(color: stroke, width: strokeW)
                : null,
          ),
        );
        break;

      case SlideShapeType.rectangle:
      case SlideShapeType.parallelogram:
        shapeBody = Container(
          decoration: BoxDecoration(
            color: fill,
            border: stroke != null
                ? Border.all(color: stroke, width: strokeW)
                : null,
          ),
        );
        break;
    }

    // Overlay text on shape if present
    if (elem.paragraphs.isNotEmpty &&
        elem.paragraphs.any((p) => p.runs.any((r) => r.text.isNotEmpty))) {
      return Stack(
        children: [
          Positioned.fill(child: shapeBody),
          Padding(
            padding: const EdgeInsets.all(4),
            child: _buildRichText(elem, scale),
          ),
        ],
      );
    }

    return shapeBody;
  }

  Widget _paintedShape({
    required Color fill,
    Color? stroke,
    required double strokeW,
    required CustomPainter painter,
  }) {
    return CustomPaint(painter: painter);
  }

  // ─────────────────────────────────────────────────────────────
  //  Image element
  // ─────────────────────────────────────────────────────────────

  Widget _buildImageElement(SlideElement elem) {
    if (elem.imageBytes == null) {
      return Container(
        color: Colors.grey.withAlpha(40),
        child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
      );
    }

    return Image.memory(
      elem.imageBytes!,
      fit: BoxFit.fill,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey.withAlpha(40),
        child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Table element
  // ─────────────────────────────────────────────────────────────

  Widget _buildTableElement(SlideElement elem, double scale) {
    if (elem.tableRows.isEmpty) return const SizedBox.shrink();

    final cols = elem.tableRows.first.length;
    if (cols == 0) return const SizedBox.shrink();

    // Column widths: use parsed widths or divide equally
    final List<double> colW = elem.tableColWidths.isNotEmpty
        ? elem.tableColWidths.map((w) => w * scale).toList()
        : List.filled(cols, elem.width * scale / cols);

    final List<double> rowH = elem.tableRowHeights.isNotEmpty
        ? elem.tableRowHeights.map((h) => h * scale).toList()
        : List.filled(elem.tableRows.length, elem.height * scale / elem.tableRows.length);

    return SingleChildScrollView(
      child: Column(
        children: List.generate(elem.tableRows.length, (ri) {
          final row = elem.tableRows[ri];
          final rh = ri < rowH.length ? rowH[ri] : 24.0 * scale;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(row.length, (ci) {
              final cell = row[ci];
              final cw = ci < colW.length ? colW[ci] : 60.0 * scale;
              final cellText = cell.paragraphs.map((p) => p.plainText).join('\n');
              final firstRun = cell.paragraphs.firstOrNull?.runs.firstOrNull;

              return Container(
                width: cw,
                height: rh,
                decoration: BoxDecoration(
                  color: cell.fillColor,
                  border: Border.all(
                    color: cell.borderColor,
                    width: cell.borderWidth,
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: 3 * scale,
                  vertical: 2 * scale,
                ),
                child: cell.paragraphs.isNotEmpty &&
                        cell.paragraphs.any((p) => p.runs.any((r) => r.text.isNotEmpty))
                    ? RichText(
                        overflow: TextOverflow.clip,
                        text: TextSpan(
                          children: cell.paragraphs
                              .expand((p) => [
                                    ...p.runs.map((r) => r.toSpan()),
                                    if (p != cell.paragraphs.last) const TextSpan(text: '\n'),
                                  ])
                              .toList(),
                        ),
                      )
                    : Text(
                        cellText,
                        style: TextStyle(
                          fontSize: (firstRun?.fontSize ?? 11) * scale,
                          color: firstRun?.color ?? Colors.black87,
                        ),
                        overflow: TextOverflow.clip,
                      ),
              );
            }),
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Fallback element (chart / SmartArt placeholder)
  // ─────────────────────────────────────────────────────────────

  Widget _buildFallbackElement(SlideElement elem, double scale) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blueGrey.withAlpha(20),
        border: Border.all(color: Colors.blueGrey.withAlpha(80), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: EdgeInsets.all(6 * scale),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_rounded,
              color: Colors.blueGrey.withAlpha(140), size: 20 * scale),
          SizedBox(height: 4 * scale),
          Text(
            elem.fallbackLabel,
            style: TextStyle(
              fontSize: (9 * scale).clamp(8.0, 14.0),
              color: Colors.blueGrey.withAlpha(180),
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Custom painters for non-rectangular shapes
// ─────────────────────────────────────────────────────────────────────────────

class _CirclePainter extends CustomPainter {
  final Color fill;
  final Color? stroke;
  final double strokeW;
  const _CirclePainter({required this.fill, this.stroke, required this.strokeW});

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(0, 0, size.width, size.height);
    if (fill != Colors.transparent) {
      canvas.drawOval(r, Paint()..color = fill);
    }
    if (stroke != null && strokeW > 0) {
      canvas.drawOval(r, Paint()..color = stroke!..style = PaintingStyle.stroke..strokeWidth = strokeW);
    }
  }

  @override
  bool shouldRepaint(_CirclePainter old) =>
      old.fill != fill || old.stroke != stroke || old.strokeW != strokeW;
}

class _TrianglePainter extends CustomPainter {
  final Color fill;
  final Color? stroke;
  final double strokeW;
  const _TrianglePainter({required this.fill, this.stroke, required this.strokeW});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    if (fill != Colors.transparent) {
      canvas.drawPath(path, Paint()..color = fill);
    }
    if (stroke != null && strokeW > 0) {
      canvas.drawPath(path, Paint()..color = stroke!..style = PaintingStyle.stroke..strokeWidth = strokeW);
    }
  }

  @override
  bool shouldRepaint(_TrianglePainter old) =>
      old.fill != fill || old.stroke != stroke || old.strokeW != strokeW;
}

class _DiamondPainter extends CustomPainter {
  final Color fill;
  final Color? stroke;
  final double strokeW;
  const _DiamondPainter({required this.fill, this.stroke, required this.strokeW});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height / 2)
      ..close();

    if (fill != Colors.transparent) {
      canvas.drawPath(path, Paint()..color = fill);
    }
    if (stroke != null && strokeW > 0) {
      canvas.drawPath(path, Paint()..color = stroke!..style = PaintingStyle.stroke..strokeWidth = strokeW);
    }
  }

  @override
  bool shouldRepaint(_DiamondPainter old) =>
      old.fill != fill || old.stroke != stroke || old.strokeW != strokeW;
}

class _LinePainter extends CustomPainter {
  final Color color;
  final double strokeW;
  const _LinePainter({required this.color, required this.strokeW});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      Paint()..color = color..strokeWidth = strokeW,
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.color != color || old.strokeW != strokeW;
}
