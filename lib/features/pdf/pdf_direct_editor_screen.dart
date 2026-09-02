import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart' as px;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../../core/app_theme.dart';
import '../../models/pdf_edit_model.dart';
import '../../services/conversion_service/conversion_service.dart';
import '../../services/pdf_service/pdf_baker_service.dart';
import '../../services/pdf_service/pdf_tools_service.dart';
import '../../services/save_manager/universal_save_manager.dart';
import '../../utils/file_utils.dart';
import 'pdf_pages_manager_screen.dart';

class PdfDirectEditorScreen extends StatefulWidget {
  final String pdfPath;
  final int initialPage;

  const PdfDirectEditorScreen({
    super.key,
    required this.pdfPath,
    this.initialPage = 1,
  });

  @override
  State<PdfDirectEditorScreen> createState() => _PdfDirectEditorScreenState();
}

class _PdfDirectEditorScreenState extends State<PdfDirectEditorScreen> {
  px.PdfDocument? _pdfDoc;
  int _pageCount = 0;
  late int _currentPage;
  Uint8List? _renderedPageBytes;
  double _pageWidth = 595.0;
  double _pageHeight = 842.0;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<PdfElement> _elements = [];
  final List<List<PdfElement>> _undoStack = [];
  final List<List<PdfElement>> _redoStack = [];

  String? _selectedElementId;
  // ignore: unused_field
  String _searchQuery = '';
  final List<Rect> _searchResults = [];

  // Replace-Text tap mode
  bool _replaceTextMode = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _loadDocument();
  }

  @override
  void dispose() {
    _pdfDoc?.close();
    super.dispose();
  }

  void _pushUndo() {
    _undoStack.add(_elements.map((e) => PdfElement.fromMap(e.toMap())).toList());
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isNotEmpty) {
      _redoStack.add(_elements.map((e) => PdfElement.fromMap(e.toMap())).toList());
      final prev = _undoStack.removeLast();
      setState(() {
        _elements.clear();
        _elements.addAll(prev);
        _selectedElementId = null;
      });
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      _undoStack.add(_elements.map((e) => PdfElement.fromMap(e.toMap())).toList());
      final next = _redoStack.removeLast();
      setState(() {
        _elements.clear();
        _elements.addAll(next);
        _selectedElementId = null;
      });
    }
  }

  Future<void> _loadDocument() async {
    setState(() => _isLoading = true);
    try {
      _pdfDoc = await px.PdfDocument.openFile(widget.pdfPath);
      _pageCount = _pdfDoc!.pagesCount;
      await _renderCurrentPage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _renderCurrentPage() async {
    if (_pdfDoc == null) return;
    final page = await _pdfDoc!.getPage(_currentPage);
    _pageWidth = page.width.toDouble();
    _pageHeight = page.height.toDouble();

    final image = await page.render(
      width: page.width * 2,
      height: page.height * 2,
      format: px.PdfPageImageFormat.png,
    );
    await page.close();

    if (mounted && image != null) {
      setState(() {
        _renderedPageBytes = image.bytes;
      });
    }
  }

  void _searchInPdf(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchResults.clear();
      });
      return;
    }

    try {
      final bytes = await File(widget.pdfPath).readAsBytes();
      final sf.PdfDocument doc = sf.PdfDocument(inputBytes: bytes);
      final extractor = sf.PdfTextExtractor(doc);

      final results =
          extractor.findText([query], startPageIndex: _currentPage - 1, endPageIndex: _currentPage - 1);
      doc.dispose();

      setState(() {
        _searchQuery = query;
        _searchResults.clear();
        for (final r in results) {
          _searchResults.add(r.bounds);
        }
      });
    } catch (_) {}
  }

  void _addTextElement({String text = 'Edit Text', double? x, double? y}) {
    _pushUndo();
    final newElem = PdfElement(
      id: 'elem_${DateTime.now().millisecondsSinceEpoch}',
      pageNumber: _currentPage,
      type: PdfElementType.text,
      x: x ?? 50,
      y: y ?? 100,
      width: 200,
      height: 40,
      text: text,
      fontSize: 16,
      textColor: Colors.black,
      backgroundColor: Colors.white,
      isBold: false,
    );

    setState(() {
      _elements.add(newElem);
      _selectedElementId = newElem.id;
    });

    _showEditTextDialog(newElem);
  }

  // ── Replace-Text: tap on page → whiteout + text overlay at that spot
  void _onPageTapForReplaceText(TapDownDetails details, Offset canvasOffset) {
    if (!_replaceTextMode) return;
    final tapX = details.localPosition.dx - canvasOffset.dx;
    final tapY = details.localPosition.dy - canvasOffset.dy;
    _showReplaceTextDialog(tapX, tapY);
  }

  void _showReplaceTextDialog(double x, double y) {
    final textController = TextEditingController();
    double fontSize = 14;
    bool isBold = false;
    bool isItalic = false;
    Color textColor = Colors.black;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.find_replace_rounded, color: Colors.orange.shade800, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Replace Text', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Type the new text. A white cover will automatically be placed under it to hide the original.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: textController,
                      autofocus: true,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Replacement Text',
                        border: OutlineInputBorder(),
                        hintText: 'Enter new text here...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Size:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Expanded(
                          child: Slider(
                            value: fontSize,
                            min: 8,
                            max: 36,
                            divisions: 28,
                            label: '${fontSize.round()} pt',
                            onChanged: (v) => setModalState(() => fontSize = v),
                          ),
                        ),
                        Text('${fontSize.round()} pt', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        FilterChip(
                          label: const Text('Bold', style: TextStyle(fontWeight: FontWeight.bold)),
                          selected: isBold,
                          onSelected: (v) => setModalState(() => isBold = v),
                        ),
                        FilterChip(
                          label: const Text('Italic', style: TextStyle(fontStyle: FontStyle.italic)),
                          selected: isItalic,
                          onSelected: (v) => setModalState(() => isItalic = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildColorDot(Colors.black, textColor, (c) => setModalState(() => textColor = c)),
                        _buildColorDot(Colors.blue.shade800, textColor, (c) => setModalState(() => textColor = c)),
                        _buildColorDot(Colors.red.shade800, textColor, (c) => setModalState(() => textColor = c)),
                        _buildColorDot(Colors.green.shade800, textColor, (c) => setModalState(() => textColor = c)),
                        _buildColorDot(Colors.orange.shade800, textColor, (c) => setModalState(() => textColor = c)),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Place on PDF'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
                  onPressed: () {
                    final replacement = textController.text.trim();
                    if (replacement.isEmpty) {
                      Navigator.pop(ctx);
                      return;
                    }
                    _pushUndo();
                    final ts = DateTime.now().millisecondsSinceEpoch;
                    // Estimate size based on text length and font size
                    final estWidth = (replacement.length * fontSize * 0.6 + 16).clamp(80.0, _pageWidth - x);
                    final lineCount = replacement.split('\n').length;
                    final estHeight = (lineCount * fontSize * 1.4 + 12).clamp(30.0, _pageHeight - y);

                    // 1. Whiteout box to hide original text
                    final whiteout = PdfElement(
                      id: 'wo_$ts',
                      pageNumber: _currentPage,
                      type: PdfElementType.whiteout,
                      x: x,
                      y: y,
                      width: estWidth,
                      height: estHeight,
                      whiteoutColor: Colors.white,
                    );

                    // 2. New text overlay
                    final textElem = PdfElement(
                      id: 'rt_$ts',
                      pageNumber: _currentPage,
                      type: PdfElementType.text,
                      x: x,
                      y: y,
                      width: estWidth,
                      height: estHeight,
                      text: replacement,
                      fontSize: fontSize,
                      textColor: textColor,
                      isBold: isBold,
                      isItalic: isItalic,
                      backgroundColor: null,
                    );

                    setState(() {
                      _elements.add(whiteout);
                      _elements.add(textElem);
                      _selectedElementId = textElem.id;
                      _replaceTextMode = false; // exit replace mode after placing
                    });
                    Navigator.pop(ctx);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Text placed! Drag to reposition. Resize with the blue handle.'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addWhiteoutBox() {
    _pushUndo();
    final newElem = PdfElement(
      id: 'elem_${DateTime.now().millisecondsSinceEpoch}',
      pageNumber: _currentPage,
      type: PdfElementType.whiteout,
      x: 50,
      y: 150,
      width: 160,
      height: 35,
      whiteoutColor: Colors.white,
    );

    setState(() {
      _elements.add(newElem);
      _selectedElementId = newElem.id;
    });
  }

  Future<void> _addImageElement() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
    );

    if (result.isNotEmpty && result.first.path != null) {
      _pushUndo();
      final imgPath = result.first.path!;
      final bytes = await File(imgPath).readAsBytes();

      final newElem = PdfElement(
        id: 'elem_${DateTime.now().millisecondsSinceEpoch}',
        pageNumber: _currentPage,
        type: PdfElementType.image,
        x: 50,
        y: 200,
        width: 140,
        height: 100,
        imagePath: imgPath,
        imageBytes: bytes,
      );

      setState(() {
        _elements.add(newElem);
        _selectedElementId = newElem.id;
      });
    }
  }

  void _showSignatureDialog() {
    final points = <Offset>[];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Draw Signature', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 300,
                height: 180,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box != null) {
                      final local = box.globalToLocal(details.globalPosition);
                      setModalState(() {
                        points.add(local);
                      });
                    }
                  },
                  onPanEnd: (_) => points.add(Offset.zero),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CustomPaint(
                      painter: _SimpleSignaturePainter(points),
                      child: const Center(
                        child: Text(
                          'Sign here with finger',
                          style: TextStyle(color: Colors.black12, fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => setModalState(() => points.clear()),
                  child: const Text('Clear'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (points.isNotEmpty) {
                      _pushUndo();
                      final sigElem = PdfElement(
                        id: 'sig_${DateTime.now().millisecondsSinceEpoch}',
                        pageNumber: _currentPage,
                        type: PdfElementType.text,
                        x: 80,
                        y: 250,
                        width: 160,
                        height: 50,
                        text: '✍ [Signature Stamp]',
                        fontSize: 14,
                        textColor: Colors.blue.shade900,
                        isBold: true,
                        isItalic: true,
                        backgroundColor: Colors.white.withAlpha(220),
                      );
                      setState(() {
                        _elements.add(sigElem);
                        _selectedElementId = sigElem.id;
                      });
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('Place Signature'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showWatermarkDialog() {
    final wmController = TextEditingController(text: 'CONFIDENTIAL');
    double opacity = 0.3;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Add Watermark', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: wmController,
                    decoration: const InputDecoration(labelText: 'Watermark Text', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Opacity:'),
                      Expanded(
                        child: Slider(
                          value: opacity,
                          min: 0.1,
                          max: 0.8,
                          onChanged: (v) => setModalState(() => opacity = v),
                        ),
                      ),
                      Text('${(opacity * 100).round()}%'),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    setState(() => _isSaving = true);
                    try {
                      final tempOut = await ConversionService.getTempOutputFile('watermarked', '.pdf');

                      await PdfToolsService.addWatermarkText(
                        inputPath: widget.pdfPath,
                        outputPath: tempOut.path,
                        watermarkText: wmController.text,
                        opacity: opacity,
                      );

                      if (!mounted) return;
                      setState(() => _isSaving = false);

                      final savedPath = await UniversalSaveManager.saveConvertedFile(
                        context: context,
                        defaultFileName: '${p.basenameWithoutExtension(widget.pdfPath)}_watermarked',
                        targetExtension: '.pdf',
                        category: DocumentCategory.pdf,
                        tempOutputFile: tempOut,
                      );

                      if (!mounted) return;
                      if (savedPath != null) {
                        nav.pop(savedPath);
                      }
                    } catch (e) {
                      if (!mounted) return;
                      setState(() => _isSaving = false);
                      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: const Text('Apply to Document'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditTextDialog(PdfElement elem) {
    final textController = TextEditingController(text: elem.text);
    double fontSize = elem.fontSize;
    bool isBold = elem.isBold;
    bool isItalic = elem.isItalic;
    bool hasWhiteoutBg = elem.backgroundColor != null;
    Color textColor = elem.textColor;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Edit Text & Style', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: textController,
                      autofocus: true,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Text Content',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Font Size Slider
                    Row(
                      children: [
                        const Text('Size:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Slider(
                            value: fontSize,
                            min: 8,
                            max: 48,
                            divisions: 40,
                            label: '${fontSize.round()}',
                            onChanged: (val) => setModalState(() => fontSize = val),
                          ),
                        ),
                        Text('${fontSize.round()} pt', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    // Bold / Italic / Whiteout Background Toggles
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        FilterChip(
                          label: const Text('Bold', style: TextStyle(fontWeight: FontWeight.bold)),
                          selected: isBold,
                          onSelected: (val) => setModalState(() => isBold = val),
                        ),
                        FilterChip(
                          label: const Text('Italic', style: TextStyle(fontStyle: FontStyle.italic)),
                          selected: isItalic,
                          onSelected: (val) => setModalState(() => isItalic = val),
                        ),
                        FilterChip(
                          label: const Text('Whiteout Bg'),
                          selected: hasWhiteoutBg,
                          onSelected: (val) => setModalState(() => hasWhiteoutBg = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Color Pick Palette
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildColorDot(Colors.black, textColor, (c) => setModalState(() => textColor = c)),
                        _buildColorDot(Colors.blue.shade800, textColor, (c) => setModalState(() => textColor = c)),
                        _buildColorDot(Colors.red.shade800, textColor, (c) => setModalState(() => textColor = c)),
                        _buildColorDot(Colors.green.shade800, textColor, (c) => setModalState(() => textColor = c)),
                        _buildColorDot(Colors.orange.shade800, textColor, (c) => setModalState(() => textColor = c)),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    _pushUndo();
                    setState(() {
                      elem.text = textController.text;
                      elem.fontSize = fontSize;
                      elem.isBold = isBold;
                      elem.isItalic = isItalic;
                      elem.textColor = textColor;
                      elem.backgroundColor = hasWhiteoutBg ? Colors.white : null;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildColorDot(Color c, Color selected, ValueChanged<Color> onSelect) {
    final isSel = selected.toARGB32() == c.toARGB32();
    return GestureDetector(
      onTap: () => onSelect(c),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: isSel ? Border.all(color: Colors.blueAccent, width: 3) : Border.all(color: Colors.grey),
        ),
      ),
    );
  }

  Future<void> _saveAndBakePdf() async {
    setState(() => _isSaving = true);
    try {
      final tempOut = await ConversionService.getTempOutputFile('edited', '.pdf');

      await PdfBakerService.bakeAndSavePdf(
        originalPdfPath: widget.pdfPath,
        elements: _elements,
        outputPath: tempOut.path,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      final savedPath = await UniversalSaveManager.saveConvertedFile(
        context: context,
        defaultFileName: '${p.basenameWithoutExtension(widget.pdfPath)}_edited',
        targetExtension: '.pdf',
        category: DocumentCategory.pdf,
        tempOutputFile: tempOut,
      );

      if (savedPath != null && mounted) {
        Navigator.pop(context, savedPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentElements = _elements.where((e) => e.pageNumber == _currentPage).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PDF Overlay Editor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              'Page $_currentPage of $_pageCount',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          // Undo
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            tooltip: 'Undo',
            onPressed: _undoStack.isNotEmpty ? _undo : null,
          ),
          // Redo
          IconButton(
            icon: const Icon(Icons.redo_rounded),
            tooltip: 'Redo',
            onPressed: _redoStack.isNotEmpty ? _redo : null,
          ),
          // Pages Manager
          IconButton(
            icon: const Icon(Icons.view_module_rounded),
            tooltip: 'Manage Pages',
            onPressed: () async {
              final nav = Navigator.of(context);
              final res = await nav.push<String>(
                MaterialPageRoute(builder: (_) => PdfPagesManagerScreen(pdfPath: widget.pdfPath)),
              );
              if (!mounted) return;
              if (res != null) {
                nav.pop(res);
              }
            },
          ),
          // Save
          IconButton.filledTonal(
            icon: const Icon(Icons.check_rounded, color: Colors.green),
            tooltip: 'Save Edited PDF',
            onPressed: _isSaving ? null : _saveAndBakePdf,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _renderedPageBytes == null
              ? const Center(child: Text('Could not render page'))
              : Column(
                  children: [
                    // Overlay Mode Notice
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      color: isDark ? Colors.blueGrey.shade900 : Colors.blue.shade50,
                      child: Row(
                        children: [
                          Icon(Icons.layers_rounded, size: 16, color: AppTheme.primaryBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Overlay Editor: Adds text, whiteout, signatures & stamps on top of PDF.',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.blue.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                      child: TextField(
                        onChanged: _searchInPdf,
                        decoration: InputDecoration(
                          hintText: 'Search text in page...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),

                    // Interactive PDF Canvas Area
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: GestureDetector(
                                onTapDown: _replaceTextMode
                                    ? (details) => _onPageTapForReplaceText(details, Offset.zero)
                                    : null,
                                child: Container(
                                  width: _pageWidth,
                                  height: _pageHeight,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: _replaceTextMode
                                        ? Border.all(color: Colors.orange.shade600, width: 2.5)
                                        : null,
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      // 1. PDF Page Rendered Image
                                      Image.memory(
                                        _renderedPageBytes!,
                                        width: _pageWidth,
                                        height: _pageHeight,
                                        fit: BoxFit.fill,
                                      ),

                                      // 2. Replace-Text mode crosshair hint
                                      if (_replaceTextMode)
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            child: Container(
                                              color: Colors.orange.withAlpha(15),
                                              child: Center(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.touch_app_rounded, color: Colors.orange.shade700, size: 48),
                                                    const SizedBox(height: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: Colors.orange.shade700,
                                                        borderRadius: BorderRadius.circular(20),
                                                      ),
                                                      child: const Text(
                                                        'Tap where you want to replace text',
                                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                      // 3. Search Highlights
                                      ..._searchResults.map((rect) {
                                        return Positioned(
                                          left: rect.left,
                                          top: rect.top,
                                          width: rect.width,
                                          height: rect.height,
                                          child: Container(
                                            color: Colors.yellow.withAlpha(120),
                                          ),
                                        );
                                      }),

                                      // 4. Editable Elements Layer (hidden during replace-text mode)
                                      if (!_replaceTextMode)
                                        ...currentElements.map((elem) => _buildEditableElement(elem)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Bottom Toolbar with Editing Tools
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        border: Border(
                          top: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: SafeArea(
                        top: false,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              // Replace Text (primary action)
                              ElevatedButton.icon(
                                icon: Icon(
                                  _replaceTextMode ? Icons.close_rounded : Icons.find_replace_rounded,
                                  size: 18,
                                  color: _replaceTextMode ? Colors.white : Colors.orange.shade800,
                                ),
                                label: Text(
                                  _replaceTextMode ? 'Cancel Replace' : 'Replace Text',
                                  style: TextStyle(
                                    color: _replaceTextMode ? Colors.white : Colors.orange.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _replaceTextMode ? Colors.orange.shade700 : Colors.orange.shade50,
                                  side: BorderSide(color: Colors.orange.shade400),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                onPressed: () => setState(() => _replaceTextMode = !_replaceTextMode),
                              ),
                              const SizedBox(width: 8),

                              // Add Text
                              TextButton.icon(
                                icon: const Icon(Icons.text_fields_rounded, size: 18),
                                label: const Text('Add Text'),
                                onPressed: () => _addTextElement(),
                              ),
                              const SizedBox(width: 4),

                              // Add Image
                              TextButton.icon(
                                icon: const Icon(Icons.image_outlined, size: 18),
                                label: const Text('Add Image'),
                                onPressed: _addImageElement,
                              ),
                              const SizedBox(width: 4),

                              // Whiteout Eraser
                              TextButton.icon(
                                icon: const Icon(Icons.layers_clear_outlined, size: 18),
                                label: const Text('Whiteout'),
                                onPressed: _addWhiteoutBox,
                              ),
                              const SizedBox(width: 4),

                              // Signature
                              TextButton.icon(
                                icon: const Icon(Icons.draw_outlined, size: 18),
                                label: const Text('Signature'),
                                onPressed: _showSignatureDialog,
                              ),
                              const SizedBox(width: 4),

                              // Watermark
                              TextButton.icon(
                                icon: const Icon(Icons.branding_watermark_outlined, size: 18),
                                label: const Text('Watermark'),
                                onPressed: _showWatermarkDialog,
                              ),

                              const VerticalDivider(width: 16),

                              // Page Navigation
                              IconButton(
                                icon: const Icon(Icons.chevron_left_rounded),
                                onPressed: _currentPage > 1
                                    ? () async {
                                        setState(() {
                                          _currentPage--;
                                          _selectedElementId = null;
                                        });
                                        await _renderCurrentPage();
                                      }
                                    : null,
                              ),
                              Text('$_currentPage/$_pageCount', style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.chevron_right_rounded),
                                onPressed: _currentPage < _pageCount
                                    ? () async {
                                        setState(() {
                                          _currentPage++;
                                          _selectedElementId = null;
                                        });
                                        await _renderCurrentPage();
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEditableElement(PdfElement elem) {
    final isSelected = elem.id == _selectedElementId;

    return Positioned(
      left: elem.x,
      top: elem.y,
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedElementId = elem.id);
        },
        onDoubleTap: () {
          if (elem.type == PdfElementType.text) {
            _showEditTextDialog(elem);
          }
        },
        onPanUpdate: (details) {
          setState(() {
            elem.x = (elem.x + details.delta.dx).clamp(0.0, _pageWidth - elem.width);
            elem.y = (elem.y + details.delta.dy).clamp(0.0, _pageHeight - elem.height);
          });
        },
        child: Container(
          width: elem.width,
          height: elem.height,
          decoration: BoxDecoration(
            border: isSelected ? Border.all(color: Colors.blueAccent, width: 2) : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Element Render Content
              Positioned.fill(child: _renderElementContent(elem)),

              // Selection Handle / Actions
              if (isSelected) ...[
                // Delete Button
                Positioned(
                  right: -12,
                  top: -12,
                  child: GestureDetector(
                    onTap: () {
                      _pushUndo();
                      setState(() {
                        _elements.removeWhere((e) => e.id == elem.id);
                        _selectedElementId = null;
                      });
                    },
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(3),
                      child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                ),

                // Edit Text Button
                if (elem.type == PdfElementType.text)
                  Positioned(
                    left: -12,
                    top: -12,
                    child: GestureDetector(
                      onTap: () => _showEditTextDialog(elem),
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                        padding: const EdgeInsets.all(3),
                        child: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ),

                // Resize Corner Handle
                Positioned(
                  right: -8,
                  bottom: -8,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        elem.width = (elem.width + details.delta.dx).clamp(30.0, _pageWidth - elem.x);
                        elem.height = (elem.height + details.delta.dy).clamp(20.0, _pageHeight - elem.y);
                      });
                    },
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _renderElementContent(PdfElement elem) {
    switch (elem.type) {
      case PdfElementType.whiteout:
        return Container(
          color: elem.whiteoutColor,
          child: const Center(
            child: Icon(Icons.layers_clear_outlined, size: 16, color: Colors.grey),
          ),
        );

      case PdfElementType.image:
        if (elem.imageBytes != null) {
          return Image.memory(elem.imageBytes!, fit: BoxFit.fill);
        } else if (elem.imagePath != null) {
          return Image.file(File(elem.imagePath!), fit: BoxFit.fill);
        }
        return Container(color: Colors.grey.shade300);

      case PdfElementType.text:
        return Container(
          color: elem.backgroundColor,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            elem.text,
            style: TextStyle(
              fontSize: elem.fontSize,
              fontWeight: elem.isBold ? FontWeight.bold : FontWeight.normal,
              fontStyle: elem.isItalic ? FontStyle.italic : FontStyle.normal,
              color: elem.textColor,
            ),
          ),
        );
    }
  }
}

class _SimpleSignaturePainter extends CustomPainter {
  final List<Offset> points;
  _SimpleSignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.shade900
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != Offset.zero && points[i + 1] != Offset.zero) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleSignaturePainter oldDelegate) => true;
}
