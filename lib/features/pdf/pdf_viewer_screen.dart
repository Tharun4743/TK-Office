import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart';
import '../../core/app_theme.dart';
import '../../services/file_service/file_service.dart';
import '../../services/pdf_service/pdf_service.dart';
import '../../services/routing/document_type_detector.dart';
import '../../services/routing/document_viewer_logger.dart';
import '../../services/routing/uri_resolver.dart';
import '../writer/unsupported_document_screen.dart';
import 'pdf_direct_editor_screen.dart';
import 'pdf_editor_screen.dart';
import 'scanned_pdf_editor_screen.dart';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;

  /// Human-readable display name (for content:// URIs).
  final String? displayName;

  const PdfViewerScreen({
    super.key,
    required this.filePath,
    this.displayName,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late String _currentPath;
  PdfControllerPinch? _pdfController;
  final FileService _fileService = FileService();
  int _pageCount = 0;
  int _currentPage = 1;
  bool _isLoading = true;
  String? _errorMessage;
  String? _resolvedDisplayName;
  bool _isTempFile = false;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.filePath;
    _resolvedDisplayName = widget.displayName;
    _initPdf();
  }

  Future<void> _initPdf() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Resolve content:// URI → local path if needed
      if (UriResolver.isContentUri(_currentPath)) {
        final resolved = await UriResolver.resolveToLocalPath(
          _currentPath,
          displayName: _resolvedDisplayName,
        );
        if (resolved == null) {
          throw Exception(
            'Could not read the PDF file from this location.\n\n'
            'Try opening it from the Downloads or Documents folder.',
          );
        }
        _currentPath = resolved;
        _isTempFile = true;
      }

      _resolvedDisplayName ??= await UriResolver.getDisplayName(widget.filePath);

      DocumentViewerLogger.logOpen(
        uri: widget.filePath,
        displayName: _resolvedDisplayName,
        detectedType: DocumentType.pdf,
      );

      if (!UriResolver.isContentUri(widget.filePath)) {
        await _fileService.recordRecentFile(_currentPath);
      }

      _pdfController = PdfControllerPinch(
        document: PdfDocument.openFile(_currentPath),
      );

      final doc = await _pdfController!.document;
      if (mounted) {
        setState(() {
          _pageCount = doc.pagesCount;
          _isLoading = false;
        });
      }

      DocumentViewerLogger.logRenderSuccess(
        type: DocumentType.pdf,
        uri: widget.filePath,
      );
    } catch (e) {
      DocumentViewerLogger.logRenderError(
        type: DocumentType.pdf,
        uri: widget.filePath,
        exception: e,
        stage: 'initPdf',
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _friendlyPdfError(e);
        });
      }
    }
  }

  String _friendlyPdfError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('permission') || msg.contains('access')) {
      return 'TK Suite does not have permission to read this PDF.\n\n'
          'Try opening it from the Downloads folder.';
    }
    if (msg.contains('not found') || msg.contains('filesystemexception')) {
      return 'The PDF file could not be found. It may have been moved or deleted.';
    }
    return 'This PDF could not be opened.\n\n'
        'The file may be corrupt, password-protected, or an unsupported PDF version.';
  }

  void _reloadPdf(String newPath) {
    _pdfController?.dispose();
    setState(() {
      _currentPath = newPath;
      _isLoading = true;
      _isTempFile = false;
    });
    _initPdf();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    if (_isTempFile) {
      UriResolver.deleteTemp(_currentPath);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show clean error screen for failed PDF loads
    if (_errorMessage != null) {
      return UnsupportedDocumentScreen(
        fileName: _resolvedDisplayName ?? p.basename(_currentPath),
        reason: _errorMessage!,
        onRetry: () => _initPdf(),
      );
    }

    final fileName = _resolvedDisplayName ?? p.basename(_currentPath);
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
          // 1. Scanned PDF OCR Editor Action
          IconButton(
            icon: const Icon(Icons.document_scanner_rounded, color: Colors.purpleAccent),
            tooltip: 'OCR Scanned PDF Editor',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ScannedPdfEditorScreen(
                    filePath: _currentPath,
                    displayName: fileName,
                  ),
                ),
              );
            },
          ),
          // 2. PDF Overlay Editor Action
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
          // 3. Freehand Annotation Action
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
          if (_pdfController != null)
            PdfViewPinch(
              controller: _pdfController!,
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
                  ? () => _pdfController?.animateToPage(
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
                  ? () => _pdfController?.animateToPage(
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
