import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart';
import '../../core/app_theme.dart';
import '../../services/file_service/file_service.dart';
import '../../services/pdf_service/pdf_service.dart';
import 'pdf_direct_editor_screen.dart';
import 'pdf_editor_screen.dart';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;

  const PdfViewerScreen({
    super.key,
    required this.filePath,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late String _currentPath;
  late PdfControllerPinch _pdfController;
  final FileService _fileService = FileService();
  int _pageCount = 0;
  int _currentPage = 1;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.filePath;
    _initPdfController();
  }

  void _initPdfController() {
    _fileService.recordRecentFile(_currentPath);
    _pdfController = PdfControllerPinch(
      document: PdfDocument.openFile(_currentPath),
    );

    _pdfController.document.then((doc) {
      if (mounted) {
        setState(() {
          _pageCount = doc.pagesCount;
          _isLoading = false;
        });
      }
    });
  }

  void _reloadPdf(String newPath) {
    _pdfController.dispose();
    setState(() {
      _currentPath = newPath;
      _isLoading = true;
    });
    _initPdfController();
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(_currentPath);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fileName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Page $_currentPage of $_pageCount',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          // 1. PDF Overlay Editor Action
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: Colors.blueAccent),
            tooltip: 'Overlay Editor (Text, Whiteout, Stamps)',
            onPressed: () async {
              final editedPath = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => PdfDirectEditorScreen(
                    pdfPath: _currentPath,
                    initialPage: _currentPage,
                  ),
                ),
              );
              if (editedPath != null && mounted) {
                _reloadPdf(editedPath);
              }
            },
          ),
          // 2. Freehand Annotation Action
          IconButton(
            icon: const Icon(Icons.draw_outlined, color: AppTheme.pdfRed),
            tooltip: 'Draw / Annotate',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PdfEditorScreen(
                    pdfPath: _currentPath,
                    currentPage: _currentPage,
                  ),
                ),
              );
            },
          ),
          // 3. Print
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print',
            onPressed: () => PdfService.printPdf(_currentPath, title: fileName),
          ),
          // 4. Share
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: () => _fileService.shareFile(_currentPath),
          ),
        ],
      ),
      body: Stack(
        children: [
          PdfViewPinch(
            controller: _pdfController,
            onPageChanged: (page) {
              setState(() {
                _currentPage = page;
              });
            },
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      bottomNavigationBar: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: 'Previous Page',
              onPressed: _currentPage > 1
                  ? () => _pdfController.animateToPage(
                        pageNumber: _currentPage - 1,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      )
                  : null,
            ),
            Text(
              '$_currentPage / $_pageCount',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              tooltip: 'Next Page',
              onPressed: _currentPage < _pageCount
                  ? () => _pdfController.animateToPage(
                        pageNumber: _currentPage + 1,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
