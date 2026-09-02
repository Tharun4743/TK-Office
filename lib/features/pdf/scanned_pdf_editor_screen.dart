import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import '../../utils/file_utils.dart';
import '../../services/ocr_service/ocr_models.dart';
import '../../services/ocr_service/ocr_pipeline_service.dart';
import '../../services/save_manager/universal_save_manager.dart';

/// Interactive editor for scanned PDFs and OCR text replacement.
class ScannedPdfEditorScreen extends StatefulWidget {
  final String filePath;
  final String displayName;

  const ScannedPdfEditorScreen({
    super.key,
    required this.filePath,
    required this.displayName,
  });

  @override
  State<ScannedPdfEditorScreen> createState() => _ScannedPdfEditorScreenState();
}

class _ScannedPdfEditorScreenState extends State<ScannedPdfEditorScreen> {
  bool _isLoading = true;
  String _statusText = 'Analyzing document...';
  int _currentPage = 1;
  int _totalPages = 1;

  PdfDocument? _pdfDocument;
  List<OCRPage> _ocrPages = [];
  final Map<String, OCRTextBlock> _modifiedBlocks = {};
  OCRTextBlock? _selectedBlock;

  @override
  void initState() {
    super.initState();
    _initOcr();
  }

  Future<void> _initOcr() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Opening document...';
    });

    try {
      _pdfDocument = await PdfDocument.openFile(widget.filePath);
      _totalPages = _pdfDocument!.pagesCount;

      setState(() {
        _statusText = 'Detecting text layers...';
      });

      _ocrPages = await OcrPipelineService.analyzePdf(
        widget.filePath,
        onProgress: (cur, total) {
          if (mounted) {
            setState(() {
              _statusText = 'Analyzing Page $cur of $total...';
            });
          }
        },
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusText = 'Error loading OCR: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _pdfDocument?.close();
    super.dispose();
  }

  void _onBlockTapped(OCRTextBlock block) {
    setState(() {
      _selectedBlock = block;
    });
    _showEditDialog(block);
  }

  void _showEditDialog(OCRTextBlock block) {
    final controller = TextEditingController(text: block.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Colors.purpleAccent),
            SizedBox(width: 8),
            Text('Edit OCR Text'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Original: ${block.text}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Replacement Text',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newText = controller.text.trim();
              if (newText.isNotEmpty && newText != block.text) {
                final updated = block.copyWith(text: newText);
                setState(() {
                  _modifiedBlocks[block.id] = updated;
                  block.text = newText;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDocument() async {
    if (_modifiedBlocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save.')),
      );
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final tempOut = File(p.join(
        tempDir.path,
        'ocr_${DateTime.now().millisecondsSinceEpoch}.pdf',
      ));

      final success = await OcrPipelineService.applyTextEdits(
        sourcePdfPath: widget.filePath,
        targetPdfPath: tempOut.path,
        modifiedBlocks: _modifiedBlocks.values.toList(),
      );

      if (!success || !await tempOut.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to generate edited PDF.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      final savedPath = await UniversalSaveManager.saveConvertedFile(
        context: context,
        defaultFileName: '${p.basenameWithoutExtension(widget.displayName)}_ocr_edited',
        targetExtension: '.pdf',
        category: DocumentCategory.pdf,
        tempOutputFile: tempOut,
      );

      if (savedPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.displayName, style: const TextStyle(fontSize: 16)),
            Text(
              'OCR Mode • Page $_currentPage/$_totalPages',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded),
            tooltip: 'Save Changes',
            onPressed: _saveDocument,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_statusText, style: const TextStyle(fontSize: 14)),
                ],
              ),
            )
          : _buildOcrPageViewer(),
    );
  }

  Widget _buildOcrPageViewer() {
    if (_ocrPages.isEmpty) {
      return const Center(child: Text('No text layers detected on this document.'));
    }

    final currentPageData = _ocrPages.firstWhere(
      (p) => p.pageIndex == _currentPage - 1,
      orElse: () => _ocrPages.first,
    );

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scaleX = constraints.maxWidth / (currentPageData.pageWidth > 0 ? currentPageData.pageWidth : 600);
              final scaleY = constraints.maxHeight / (currentPageData.pageHeight > 0 ? currentPageData.pageHeight : 800);
              final scale = scaleX < scaleY ? scaleX : scaleY;

              return Center(
                child: Container(
                  width: currentPageData.pageWidth * scale,
                  height: currentPageData.pageHeight * scale,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Render OCR text blocks with highlight borders
                      ...currentPageData.blocks.map((block) {
                        final isSelected = _selectedBlock?.id == block.id;
                        final isModified = _modifiedBlocks.containsKey(block.id);

                        return Positioned(
                          left: block.boundingBox.left * scale,
                          top: block.boundingBox.top * scale,
                          width: block.boundingBox.width * scale,
                          height: block.boundingBox.height * scale,
                          child: GestureDetector(
                            onTap: () => _onBlockTapped(block),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isModified
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : (isSelected
                                        ? Colors.blue.withValues(alpha: 0.3)
                                        : Colors.amber.withValues(alpha: 0.08)),
                                border: Border.all(
                                  color: isModified
                                      ? Colors.green
                                      : (isSelected ? Colors.blue : Colors.amber.withValues(alpha: 0.4)),
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Center(
                                child: Text(
                                  block.text,
                                  style: TextStyle(
                                    fontSize: (block.fontSize * scale).clamp(8.0, 24.0),
                                    color: block.textColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Bottom pagination bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).cardColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
              ),
              Text('Page $_currentPage of $_totalPages'),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _currentPage < _totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
