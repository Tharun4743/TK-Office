import 'dart:io';

import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:path/path.dart' as p;

import '../../services/document_service/doc_binary_service.dart';
import '../../services/document_service/docx_service.dart';
import '../../services/document_service/rtf_txt_service.dart';
import '../../services/file_service/file_service.dart';
import '../../services/routing/document_type_detector.dart';
import '../../services/routing/document_viewer_logger.dart';
import '../../services/routing/uri_resolver.dart';
import 'unsupported_document_screen.dart';
import 'writer_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// View States
// ─────────────────────────────────────────────────────────────────────────────

abstract class _DocxViewState {}

class _LoadingState extends _DocxViewState {}

class _ContentState extends _DocxViewState {
  final QuillController controller;
  final String displayName;
  _ContentState({required this.controller, required this.displayName});
}

class _ErrorState extends _DocxViewState {
  final String message;
  _ErrorState(this.message);
}

// ─────────────────────────────────────────────────────────────────────────────
// DocxViewerScreen
// ─────────────────────────────────────────────────────────────────────────────

/// READ-ONLY document viewer for DOCX / DOC / RTF / TXT / ODT files.
///
/// ✓ Reuses existing [DocxService] — no competing DOCX implementation
/// ✓ QuillEditor in readOnly=true mode — NO WriterToolbar at bottom
/// ✓ Page-like white card on grey background (simulates A4 page)
/// ✓ Three clear states: Loading → Content → Error (never shows partial output)
/// ✓ Handles content:// URIs via [UriResolver]
/// ✓ Temp copies of content:// URIs deleted on dispose
/// ✓ Parsing done via async Future.microtask to keep UI thread free during I/O
class DocxViewerScreen extends StatefulWidget {
  /// File-system path OR content:// URI.
  final String filePath;

  /// Human-readable filename (needed for content:// URIs).
  final String? displayName;

  /// Detected document type — determines parser branch.
  final DocumentType documentType;

  const DocxViewerScreen({
    super.key,
    required this.filePath,
    this.displayName,
    this.documentType = DocumentType.docx,
  });

  @override
  State<DocxViewerScreen> createState() => _DocxViewerScreenState();
}

class _DocxViewerScreenState extends State<DocxViewerScreen> {
  _DocxViewState _state = _LoadingState();
  String? _resolvedLocalPath;
  bool _isTempFile = false;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  @override
  void dispose() {
    final s = _state;
    if (s is _ContentState) {
      s.controller.dispose();
    }
    // Delete temp file (only if it is inside the cache temp folder)
    if (_isTempFile && _resolvedLocalPath != null) {
      UriResolver.deleteTemp(_resolvedLocalPath);
    }
    super.dispose();
  }

  // ── Load Pipeline ───────────────────────────────────────────────────────

  Future<void> _loadDocument() async {
    if (mounted) setState(() => _state = _LoadingState());

    try {
      // 1. Resolve content:// → real file path
      String localPath = widget.filePath;
      final bool isContent = UriResolver.isContentUri(widget.filePath);

      if (isContent) {
        final resolved = await UriResolver.resolveToLocalPath(
          widget.filePath,
          displayName: widget.displayName,
        );
        if (resolved == null) {
          throw Exception(
            'Could not access this file.\n\n'
            'It may require additional storage permissions, or the file provider '
            'does not allow external reading.',
          );
        }
        _resolvedLocalPath = resolved;
        _isTempFile = true;
        localPath = resolved;
      }

      // 2. Display name
      final displayName =
          widget.displayName ?? await UriResolver.getDisplayName(widget.filePath);

      // 3. Diagnostic log
      final int? fileSize =
          File(localPath).existsSync() ? await File(localPath).length() : null;
      DocumentViewerLogger.logOpen(
        uri: widget.filePath,
        displayName: displayName,
        detectedType: widget.documentType,
        fileSizeBytes: fileSize,
        parserName: _parserLabel(),
      );

      // 4. Parse document (async I/O — keeps UI responsive)
      final delta = await _parseDocument(localPath);

      // 5. Build read-only Quill controller (on UI thread)
      final quillDoc = Document.fromDelta(delta);
      final controller = QuillController(
        document: quillDoc,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );

      DocumentViewerLogger.logRenderSuccess(
        type: widget.documentType,
        uri: widget.filePath,
      );

      if (mounted) {
        setState(() {
          _state = _ContentState(controller: controller, displayName: displayName);
        });
      }
    } catch (e, st) {
      DocumentViewerLogger.logRenderError(
        type: widget.documentType,
        uri: widget.filePath,
        exception: e,
        stage: 'load',
      );
      debugPrint('[DocxViewerScreen] ERROR: $e\n$st');
      if (mounted) {
        setState(() => _state = _ErrorState(_friendlyError(e)));
      }
    }
  }

  /// Parses the document at [localPath] and returns a Quill [Delta].
  /// All file I/O is async, keeping the UI thread free.
  Future<Delta> _parseDocument(String localPath) async {
    switch (widget.documentType) {
      case DocumentType.docx:
      case DocumentType.odt:
        return DocxService.importDocx(localPath);

      case DocumentType.doc:
        // Try OOXML first (some .doc files are renamed DOCX)
        final d1 = await DocxService.importDocx(localPath);
        final ops = d1.toList();
        final first =
            ops.isNotEmpty && ops.first.data is String ? ops.first.data as String : '';
        if (first.startsWith('Could not read') ||
            first.startsWith('Error reading')) {
          // Binary fallback
          return DocBinaryService.importDoc(localPath);
        }
        return d1;

      case DocumentType.rtf:
        return RtfTxtService.importRtf(localPath);

      case DocumentType.txt:
      case DocumentType.csv:
        return RtfTxtService.importTxt(localPath);

      default:
        // Best-effort DOCX parse for unknown/odt
        return DocxService.importDocx(localPath);
    }
  }

  String _parserLabel() {
    switch (widget.documentType) {
      case DocumentType.docx:
      case DocumentType.odt:
        return 'DocxService (OOXML)';
      case DocumentType.doc:
        return 'DocxService → DocBinaryService';
      case DocumentType.rtf:
        return 'RtfTxtService';
      case DocumentType.txt:
      case DocumentType.csv:
        return 'RtfTxtService (plain text)';
      default:
        return 'DocxService';
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('permission') || msg.contains('access')) {
      return 'TK Suite does not have permission to read this file.\n\n'
          'Try opening it from the Documents or Downloads folder.';
    }
    if (msg.contains('not found') ||
        msg.contains('does not exist') ||
        msg.contains('filesystemexception')) {
      return 'The file could not be found.\n\n'
          'It may have been moved or deleted.';
    }
    return 'The document could not be rendered.\n\n'
        'Try opening it again, or use the Conversion Center to convert it '
        'to PDF for preview.';
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = _state;

    if (state is _ErrorState) {
      return UnsupportedDocumentScreen(
        fileName: _effectiveDisplayName(),
        reason: state.message,
        onRetry: _loadDocument,
      );
    }

    if (state is _ContentState) {
      return _buildDocumentView(state);
    }

    return _buildLoadingScaffold();
  }

  // ── Loading Scaffold ────────────────────────────────────────────────────

  Widget _buildLoadingScaffold() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _effectiveDisplayName(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'Rendering document…',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // ── Document View ───────────────────────────────────────────────────────

  Widget _buildDocumentView(_ContentState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.displayName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'Read-only preview',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: _handleMenuAction,
            itemBuilder: (_) => [
              // Only show Edit for real local files (not content:// temp copies)
              if (!UriResolver.isContentUri(widget.filePath))
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Open in Editor'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Share'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      // ── NO WriterToolbar — this is VIEW-ONLY mode ────────────────────────
      body: Container(
        color: isDark ? const Color(0xFF0B1120) : const Color(0xFFEEF2F7),
        child: Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                // Simulate A4 page width
                constraints: const BoxConstraints(maxWidth: 720),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 50 : 18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  // A4-like page margins
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 40,
                  ),
                  child: QuillEditor(
                    controller: state.controller,
                    scrollController: ScrollController(),
                    focusNode: FocusNode(canRequestFocus: false),
                    config: const QuillEditorConfig(
                      showCursor: false,
                      autoFocus: false,
                      scrollable: false, // outer scroll handles scrolling
                      expands: false,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        final editPath = _resolvedLocalPath ?? widget.filePath;
        if (!UriResolver.isContentUri(editPath)) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WriterScreen(filePath: editPath),
            ),
          );
        }
        break;
      case 'share':
        final sharePath = _resolvedLocalPath ?? widget.filePath;
        if (!UriResolver.isContentUri(sharePath)) {
          FileService().shareFile(sharePath);
        }
        break;
    }
  }

  String _effectiveDisplayName() {
    if (widget.displayName != null && widget.displayName!.isNotEmpty) {
      return widget.displayName!;
    }
    if (!UriResolver.isContentUri(widget.filePath)) {
      return p.basename(widget.filePath);
    }
    return 'Document';
  }
}
