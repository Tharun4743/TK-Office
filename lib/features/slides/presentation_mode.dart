import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/presentation_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PresentationModeScreen
//  Full-screen presentation viewer. Swipe left/right to change slides.
//  Uses the same rich rendering pipeline as SlideCanvas:
//    • Background (solid / gradient / image)
//    • Rich text, shapes, images, tables, fallback placeholders
// ─────────────────────────────────────────────────────────────────────────────

class PresentationModeScreen extends StatefulWidget {
  final PresentationModel presentation;
  final int initialSlideIndex;

  const PresentationModeScreen({
    super.key,
    required this.presentation,
    this.initialSlideIndex = 0,
  });

  @override
  State<PresentationModeScreen> createState() => _PresentationModeScreenState();
}

class _PresentationModeScreenState extends State<PresentationModeScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialSlideIndex;
    _pageController = PageController(initialPage: _currentIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.presentation.slides;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _controlsVisible = !_controlsVisible),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemCount: slides.length,
              itemBuilder: (context, index) {
                final slide = slides[index];
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          final scale = constraints.maxWidth / slide.slideWidth;
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              children: [
                                // Background
                                Positioned.fill(child: _buildBackground(slide)),
                                // Elements
                                ...slide.elements.map(
                                  (elem) => _buildPositioned(elem, scale),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),

            // Controls overlay
            if (_controlsVisible)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_currentIndex + 1} / ${slides.length}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Background
  // ─────────────────────────────────────────────────────────────

  Widget _buildBackground(SlideModel slide) {
    if (slide.backgroundImageBytes != null) {
      return Image.memory(
        slide.backgroundImageBytes!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(color: slide.backgroundColor),
      );
    }
    if (slide.backgroundGradientColors.length >= 2) {
      final angle = slide.backgroundGradientAngle * math.pi / 180.0;
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: slide.backgroundGradientColors,
            begin: Alignment(-math.cos(angle + math.pi / 2), -math.sin(angle + math.pi / 2)),
            end: Alignment(math.cos(angle + math.pi / 2), math.sin(angle + math.pi / 2)),
          ),
        ),
      );
    }
    return Container(color: slide.backgroundColor);
  }

  // ─────────────────────────────────────────────────────────────
  //  Element rendering (mirrors SlideCanvas)
  // ─────────────────────────────────────────────────────────────

  Widget _buildPositioned(SlideElement elem, double scale) {
    Widget inner = _buildElement(elem, scale);

    if (elem.opacity < 0.999) {
      inner = Opacity(opacity: elem.opacity.clamp(0.0, 1.0), child: inner);
    }
    if (elem.rotation.abs() > 0.01) {
      inner = Transform.rotate(angle: elem.rotation * math.pi / 180.0, child: inner);
    }

    return Positioned(
      left: elem.x * scale,
      top: elem.y * scale,
      width: elem.width * scale,
      height: elem.height * scale,
      child: inner,
    );
  }

  Widget _buildElement(SlideElement elem, double scale) {
    switch (elem.type) {
      case SlideElementType.text:
        return _buildText(elem, scale);
      case SlideElementType.shape:
        return _buildShape(elem, scale);
      case SlideElementType.image:
        return elem.imageBytes != null
            ? Image.memory(elem.imageBytes!, fit: BoxFit.fill,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink())
            : const SizedBox.shrink();
      case SlideElementType.table:
        return _buildTable(elem, scale);
      case SlideElementType.fallback:
        return Container(
          decoration: BoxDecoration(
            color: Colors.blueGrey.withAlpha(20),
            border: Border.all(color: Colors.blueGrey.withAlpha(80)),
          ),
          alignment: Alignment.center,
          child: Text(
            elem.fallbackLabel,
            style: TextStyle(fontSize: (9 * scale).clamp(8, 14).toDouble(), color: Colors.blueGrey),
            textAlign: TextAlign.center,
          ),
        );
    }
  }

  Widget _buildText(SlideElement elem, double scale) {
    if (elem.paragraphs.isNotEmpty &&
        elem.paragraphs.any((p) => p.runs.any((r) => r.text.isNotEmpty))) {
      final spans = <InlineSpan>[];
      for (var pi = 0; pi < elem.paragraphs.length; pi++) {
        final para = elem.paragraphs[pi];
        for (final run in para.runs) {
          spans.add(TextSpan(
            text: run.text,
            style: TextStyle(
              fontSize: (run.fontSize * scale).clamp(4, 200).toDouble(),
              fontWeight: run.isBold ? FontWeight.bold : FontWeight.normal,
              fontStyle: run.isItalic ? FontStyle.italic : FontStyle.normal,
              decoration: run.textDecoration,
              color: run.color,
              fontFamily: run.fontFamily,
              height: para.lineSpacing > 0 ? para.lineSpacing : null,
            ),
          ));
        }
        if (pi < elem.paragraphs.length - 1) spans.add(const TextSpan(text: '\n'));
      }
      return Container(
        color: elem.fillColor,
        padding: const EdgeInsets.all(2),
        child: RichText(
          text: TextSpan(children: spans),
          textAlign: elem.paragraphs.firstOrNull?.align ?? elem.align,
          overflow: TextOverflow.clip,
        ),
      );
    }
    return Container(
      color: elem.fillColor,
      padding: const EdgeInsets.all(2),
      child: Text(
        elem.content,
        style: TextStyle(
          fontSize: elem.fontSize * scale,
          fontWeight: elem.isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: elem.isItalic ? FontStyle.italic : FontStyle.normal,
          color: elem.textColor,
        ),
        textAlign: elem.align,
        overflow: TextOverflow.clip,
      ),
    );
  }

  Widget _buildShape(SlideElement elem, double scale) {
    final fill = elem.fillColor ?? Colors.blueGrey.withAlpha(80);
    final stroke = elem.strokeColor;
    final sw = (elem.strokeWidth * scale).clamp(0.0, 8.0);

    switch (elem.shapeType) {
      case SlideShapeType.circle:
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: stroke != null ? Border.all(color: stroke, width: sw) : null,
          ),
        );
      case SlideShapeType.roundedRectangle:
        return Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(8 * scale),
            border: stroke != null ? Border.all(color: stroke, width: sw) : null,
          ),
        );
      default:
        return Container(
          decoration: BoxDecoration(
            color: fill,
            border: stroke != null ? Border.all(color: stroke, width: sw) : null,
          ),
        );
    }
  }

  Widget _buildTable(SlideElement elem, double scale) {
    if (elem.tableRows.isEmpty) return const SizedBox.shrink();
    final cols = elem.tableRows.first.length;
    if (cols == 0) return const SizedBox.shrink();

    final colW = elem.tableColWidths.isNotEmpty
        ? elem.tableColWidths.map((w) => w * scale).toList()
        : List.filled(cols, elem.width * scale / cols);
    final rowH = elem.tableRowHeights.isNotEmpty
        ? elem.tableRowHeights.map((h) => h * scale).toList()
        : List.filled(elem.tableRows.length, elem.height * scale / elem.tableRows.length);

    return SingleChildScrollView(
      child: Column(
        children: List.generate(elem.tableRows.length, (ri) {
          final rh = ri < rowH.length ? rowH[ri] : 20.0 * scale;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(elem.tableRows[ri].length, (ci) {
              final cell = elem.tableRows[ri][ci];
              final cw = ci < colW.length ? colW[ci] : 50.0 * scale;
              final text = cell.paragraphs.map((p) => p.plainText).join('\n');
              final firstRun = cell.paragraphs.firstOrNull?.runs.firstOrNull;
              return Container(
                width: cw,
                height: rh,
                decoration: BoxDecoration(
                  color: cell.fillColor,
                  border: Border.all(color: cell.borderColor, width: cell.borderWidth),
                ),
                padding: EdgeInsets.all(2 * scale),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: (firstRun?.fontSize ?? 10) * scale,
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
}
