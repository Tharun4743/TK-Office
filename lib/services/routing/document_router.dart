import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../features/pdf/pdf_viewer_screen.dart';
import '../../features/sheets/sheets_screen.dart';
import '../../features/slides/slides_screen.dart';
import '../../features/writer/docx_viewer_screen.dart';
import '../../features/writer/unsupported_document_screen.dart';
import '../../services/file_service/file_service.dart';
import '../../services/routing/document_type_detector.dart';
import '../../services/routing/document_validator.dart';
import '../../services/routing/document_viewer_logger.dart';
import '../../services/routing/uri_resolver.dart';

/// Central document routing hub.
///
/// Routes any file (local path OR content:// URI) to the correct viewer:
///
///   PDF    → PdfViewerScreen
///   DOCX   → DocxViewerScreen (READ-ONLY)
///   DOC    → DocxViewerScreen (OOXML → binary fallback)
///   PPTX   → SlidesScreen (existing slide viewer, unchanged)
///   PPT    → SlidesScreen
///   XLSX   → SheetsScreen
///   XLS    → SheetsScreen
///   TXT    → DocxViewerScreen (plain text, read-only)
///   RTF    → DocxViewerScreen (stripped RTF, read-only)
///   ODT    → DocxViewerScreen (OOXML best-effort)
///   CSV    → SheetsScreen
///   Other  → UnsupportedDocumentScreen
///
/// IMPORTANT: Opening a document for VIEWING never triggers the conversion
/// workflow. Temporary files are never shown in the user's Documents list.
class DocumentRouter {
  static final FileService _fileService = FileService();

  /// Route [pathOrUri] to the appropriate viewer.
  ///
  /// [pathOrUri] may be:
  ///   - An absolute file-system path
  ///   - A content:// URI (resolved as needed by each viewer)
  ///
  /// [displayName] overrides the filename shown in the app bar
  /// (required for content:// URIs that have no readable path segment).
  ///
  /// [mimeType] is forwarded to [DocumentTypeDetector] for better accuracy.
  static Future<void> routeDocument(
    BuildContext context,
    String pathOrUri, {
    String? displayName,
    String? mimeType,
  }) async {
    // 1. Resolve display name
    final name = displayName ?? await UriResolver.getDisplayName(pathOrUri);

    // 2. Detect document type
    final docType = await DocumentTypeDetector.detect(
      pathOrUri,
      displayName: name,
      mimeType: mimeType,
    );

    // 3. Log diagnostic info
    DocumentViewerLogger.logOpen(
      uri: pathOrUri,
      displayName: name,
      mimeType: mimeType,
      extension: p.extension(name).toLowerCase(),
      detectedType: docType,
    );

    // 4. Validate (only for real file paths — content:// URIs are validated
    //    inside each viewer after UriResolver copies them)
    if (!UriResolver.isContentUri(pathOrUri)) {
      final validation = await DocumentValidator.validateFile(pathOrUri, docType);
      if (!validation.isOk) {
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => UnsupportedDocumentScreen(
                fileName: name,
                reason: validation.displayMessage,
              ),
            ),
          );
        }
        return;
      }
    }

    // 5. Record as recent file (only for real paths)
    if (!UriResolver.isContentUri(pathOrUri)) {
      await _fileService.recordRecentFile(pathOrUri);
    }

    if (!context.mounted) return;

    // 6. Route to the correct viewer
    switch (docType) {
      // ── PDF ────────────────────────────────────────────────────────────
      case DocumentType.pdf:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PdfViewerScreen(
              filePath: pathOrUri,
              displayName: name,
            ),
          ),
        );

      // ── DOCX / DOC / RTF / TXT / ODT ──────────────────────────────────
      case DocumentType.docx:
      case DocumentType.doc:
      case DocumentType.rtf:
      case DocumentType.txt:
      case DocumentType.odt:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DocxViewerScreen(
              filePath: pathOrUri,
              displayName: name,
              documentType: docType,
            ),
          ),
        );

      // ── PPTX / PPT ────────────────────────────────────────────────────
      case DocumentType.pptx:
      case DocumentType.ppt:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SlidesScreen(filePath: pathOrUri),
          ),
        );

      // ── XLSX / XLS / CSV ─────────────────────────────────────────────
      case DocumentType.xlsx:
      case DocumentType.xls:
      case DocumentType.csv:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SheetsScreen(filePath: pathOrUri),
          ),
        );

      // ── Unsupported ───────────────────────────────────────────────────
      case DocumentType.unsupported:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UnsupportedDocumentScreen(
              fileName: name,
              reason:
                  'TK Suite does not support this file type.\n\n'
                  'Supported formats: PDF, DOCX, DOC, PPTX, PPT, XLSX, XLS, '
                  'RTF, TXT, ODT, CSV.',
            ),
          ),
        );
    }
  }

  /// Legacy entry point that accepts a file-system path.
  /// Kept for backward compatibility with all existing callers.
  ///
  /// [isExternal] is DEPRECATED — the "import copy" dialog has been removed
  /// because viewing must never add files to the user's Documents directory.
  static Future<void> routeDocumentLegacy(
    BuildContext context,
    String filePath, {
    @Deprecated('Import dialog removed — viewing does not copy files')
    bool isExternal = false,
  }) =>
      routeDocument(context, filePath);
}
