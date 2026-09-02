import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/pdf_annotation_model.dart';
import '../../services/pdf_service/pdf_service.dart';
import '../../shared/widgets/tk_dialogs.dart';

class PdfEditorScreen extends StatefulWidget {
  final String pdfPath;
  final int currentPage;

  const PdfEditorScreen({
    super.key,
    required this.pdfPath,
    required this.currentPage,
  });

  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  final List<DrawingPoint?> _points = [];
  final List<PdfAnnotation> _savedAnnotations = [];
  Color _selectedColor = Colors.yellow.shade700;
  final double _strokeWidth = 4.0;
  bool _isHighlightMode = false;
  bool _isEraserMode = false;

  @override
  void initState() {
    super.initState();
    _loadExistingAnnotations();
  }

  Future<void> _loadExistingAnnotations() async {
    final list = await PdfService.loadAnnotations(widget.pdfPath);
    setState(() {
      _savedAnnotations.addAll(list.where((a) => a.pageNumber == widget.currentPage));
    });
  }

  Future<void> _saveAnnotations() async {
    final all = await PdfService.loadAnnotations(widget.pdfPath);
    all.removeWhere((a) => a.pageNumber == widget.currentPage);
    all.addAll(_savedAnnotations);
    await PdfService.saveAnnotations(widget.pdfPath, all);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Annotations saved ✓')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Annotate Page ${widget.currentPage}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            tooltip: 'Undo Stroke',
            onPressed: () {
              if (_points.isNotEmpty) {
                setState(() => _points.removeLast());
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear Page Annotations',
            onPressed: () {
              setState(() {
                _points.clear();
                _savedAnnotations.clear();
              });
            },
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.pdfRed,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Save'),
            onPressed: _saveAnnotations,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Background Canvas (Drawing Overlay)
          Container(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            child: GestureDetector(
              onPanStart: (details) {
                setState(() {
                  _points.add(
                    DrawingPoint(
                      offset: details.localPosition,
                      paint: Paint()
                        ..color = _isEraserMode
                            ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC))
                            : (_isHighlightMode ? _selectedColor.withAlpha(100) : _selectedColor)
                        ..isAntiAlias = true
                        ..strokeWidth = _isHighlightMode ? 14.0 : (_isEraserMode ? 24.0 : _strokeWidth)
                        ..strokeCap = StrokeCap.round,
                    ),
                  );
                });
              },
              onPanUpdate: (details) {
                setState(() {
                  _points.add(
                    DrawingPoint(
                      offset: details.localPosition,
                      paint: Paint()
                        ..color = _isEraserMode
                            ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC))
                            : (_isHighlightMode ? _selectedColor.withAlpha(100) : _selectedColor)
                        ..isAntiAlias = true
                        ..strokeWidth = _isHighlightMode ? 14.0 : (_isEraserMode ? 24.0 : _strokeWidth)
                        ..strokeCap = StrokeCap.round,
                    ),
                  );
                });
              },
              onPanEnd: (_) {
                setState(() {
                  _points.add(null);
                });
              },
              child: CustomPaint(
                painter: _PdfDrawingPainter(_points),
                size: Size.infinite,
              ),
            ),
          ),

          // Render Text Notes
          ..._savedAnnotations.where((a) => a.type == AnnotationType.text).map((a) {
            return Positioned(
              left: a.points.isNotEmpty ? a.points.first.dx : 40,
              top: a.points.isNotEmpty ? a.points.first.dy : 40,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade700),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Text(
                  a.text,
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                ),
              ),
            );
          }),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Pen Mode
              IconButton(
                icon: Icon(
                  Icons.edit_rounded,
                  color: (!_isHighlightMode && !_isEraserMode) ? AppTheme.pdfRed : null,
                ),
                tooltip: 'Pen',
                onPressed: () {
                  setState(() {
                    _isHighlightMode = false;
                    _isEraserMode = false;
                  });
                },
              ),

              // Highlighter Mode
              IconButton(
                icon: Icon(
                  Icons.highlight_rounded,
                  color: _isHighlightMode ? AppTheme.pdfRed : null,
                ),
                tooltip: 'Highlighter',
                onPressed: () {
                  setState(() {
                    _isHighlightMode = true;
                    _isEraserMode = false;
                  });
                },
              ),

              // Eraser Mode
              IconButton(
                icon: Icon(
                  Icons.cleaning_services_rounded,
                  color: _isEraserMode ? AppTheme.pdfRed : null,
                ),
                tooltip: 'Eraser',
                onPressed: () {
                  setState(() {
                    _isEraserMode = true;
                    _isHighlightMode = false;
                  });
                },
              ),

              // Add Text Note
              IconButton(
                icon: const Icon(Icons.note_add_outlined),
                tooltip: 'Add Sticky Note',
                onPressed: () async {
                  final text = await TKDialogs.showNameInputDialog(
                    context: context,
                    title: 'Add Text Annotation',
                    initialValue: '',
                    hintText: 'Enter your note here...',
                    actionLabel: 'Add Note',
                  );
                  if (text != null && text.isNotEmpty) {
                    setState(() {
                      _savedAnnotations.add(
                        PdfAnnotation(
                          id: 'note_${DateTime.now().millisecondsSinceEpoch}',
                          pageNumber: widget.currentPage,
                          type: AnnotationType.text,
                          points: [const Offset(40, 100)],
                          text: text,
                        ),
                      );
                    });
                  }
                },
              ),

              // Color Palette Selector
              _buildColorCircle(Colors.yellow.shade700),
              _buildColorCircle(Colors.redAccent),
              _buildColorCircle(Colors.blueAccent),
              _buildColorCircle(Colors.green),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorCircle(Color color) {
    final isSelected = _selectedColor == color && !_isEraserMode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = color;
          _isEraserMode = false;
        });
      },
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: isSelected ? [const BoxShadow(color: Colors.black45, blurRadius: 4)] : null,
        ),
      ),
    );
  }
}

class _PdfDrawingPainter extends CustomPainter {
  final List<DrawingPoint?> points;

  _PdfDrawingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(
          points[i]!.offset,
          points[i + 1]!.offset,
          points[i]!.paint,
        );
      } else if (points[i] != null && points[i + 1] == null) {
        canvas.drawCircle(
          points[i]!.offset,
          points[i]!.paint.strokeWidth / 2,
          points[i]!.paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
