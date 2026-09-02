import 'dart:io';

import 'package:flutter/foundation.dart';

/// All document types that TK Suite can handle.
enum DocumentType {
  pdf,
  docx,
  doc,
  pptx,
  ppt,
  xlsx,
  xls,
  odt,
  rtf,
  txt,
  csv,
  unsupported,
}

/// Detects the document type from a file path or content:// URI.
///
/// Detection order:
///  1. File extension (most reliable when available)
///  2. File magic bytes (ZIP = Office XML family; %PDF = PDF)
///
/// NEVER relies on file:// conversion from content:// URIs.
class DocumentTypeDetector {
  // ── Extension map ────────────────────────────────────────────────────────
  static const Map<String, DocumentType> _extensionMap = {
    '.pdf': DocumentType.pdf,
    '.docx': DocumentType.docx,
    '.doc': DocumentType.doc,
    '.pptx': DocumentType.pptx,
    '.ppt': DocumentType.ppt,
    '.xlsx': DocumentType.xlsx,
    '.xls': DocumentType.xls,
    '.odt': DocumentType.odt,
    '.rtf': DocumentType.rtf,
    '.txt': DocumentType.txt,
    '.text': DocumentType.txt,
    '.csv': DocumentType.csv,
  };

  // ── Magic bytes ──────────────────────────────────────────────────────────
  // ZIP magic (PK\x03\x04) → could be DOCX, PPTX, XLSX, ODT
  static const List<int> _zipMagic = [0x50, 0x4B, 0x03, 0x04];
  // PDF magic (%PDF)
  static const List<int> _pdfMagic = [0x25, 0x50, 0x44, 0x46];
  // OLE2 compound doc (DOC, XLS, PPT legacy)
  static const List<int> _oleMagic = [0xD0, 0xCF, 0x11, 0xE0];
  // RTF magic ({\rtf)
  static const List<int> _rtfMagic = [0x7B, 0x5C, 0x72, 0x74, 0x66];

  /// Detect the document type for [pathOrUri].
  ///
  /// [pathOrUri] may be:
  ///   - An absolute file system path: `/storage/emulated/0/Download/file.docx`
  ///   - A content URI already resolved to a local cache path (by [UriResolver])
  ///   - A content:// URI string (only extension parsed; magic bytes not read)
  ///
  /// [displayName] is the human-readable filename (e.g. from OpenableColumns).
  /// Provide it for content:// URIs where the path has no usable extension.
  static Future<DocumentType> detect(
    String pathOrUri, {
    String? displayName,
    String? mimeType,
  }) async {
    debugPrint('[DocumentTypeDetector] pathOrUri=$pathOrUri '
        'displayName=$displayName mimeType=$mimeType');

    // 1. Try extension from displayName (most reliable for content:// URIs)
    if (displayName != null && displayName.isNotEmpty) {
      final t = _fromExtension(displayName);
      if (t != DocumentType.unsupported) {
        debugPrint('[DocumentTypeDetector] resolved via displayName → $t');
        return t;
      }
    }

    // 2. Try extension from the path/URI itself
    final t = _fromExtension(pathOrUri);
    if (t != DocumentType.unsupported) {
      debugPrint('[DocumentTypeDetector] resolved via path ext → $t');
      return t;
    }

    // 3. Try MIME type (from Android intent / file picker)
    if (mimeType != null && mimeType.isNotEmpty) {
      final mt = _fromMime(mimeType);
      if (mt != DocumentType.unsupported) {
        debugPrint('[DocumentTypeDetector] resolved via MIME → $mt');
        return mt;
      }
    }

    // 4. Magic bytes — only possible if this is a real file path
    if (!pathOrUri.startsWith('content://')) {
      final magic = await _readMagicBytes(pathOrUri);
      if (magic != null) {
        final mb = _fromMagicBytes(magic);
        if (mb != DocumentType.unsupported) {
          debugPrint('[DocumentTypeDetector] resolved via magic bytes → $mb');
          return mb;
        }
      }
    }

    debugPrint('[DocumentTypeDetector] unsupported');
    return DocumentType.unsupported;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static DocumentType _fromExtension(String nameOrPath) {
    final lower = nameOrPath.toLowerCase();
    // Find last '.'
    final dotIdx = lower.lastIndexOf('.');
    if (dotIdx < 0) return DocumentType.unsupported;
    final ext = lower.substring(dotIdx);
    return _extensionMap[ext] ?? DocumentType.unsupported;
  }

  static DocumentType _fromMime(String mime) {
    switch (mime) {
      case 'application/pdf':
        return DocumentType.pdf;
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return DocumentType.docx;
      case 'application/msword':
        return DocumentType.doc;
      case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        return DocumentType.pptx;
      case 'application/vnd.ms-powerpoint':
        return DocumentType.ppt;
      case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        return DocumentType.xlsx;
      case 'application/vnd.ms-excel':
        return DocumentType.xls;
      case 'application/vnd.oasis.opendocument.text':
        return DocumentType.odt;
      case 'application/rtf':
      case 'text/rtf':
        return DocumentType.rtf;
      case 'text/plain':
        return DocumentType.txt;
      case 'text/csv':
      case 'application/csv':
        return DocumentType.csv;
      default:
        return DocumentType.unsupported;
    }
  }

  static Future<Uint8List?> _readMagicBytes(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final raf = await file.open();
      final buf = Uint8List(8);
      final read = await raf.readInto(buf, 0, 8);
      await raf.close();
      return read > 0 ? buf.sublist(0, read) : null;
    } catch (_) {
      return null;
    }
  }

  static DocumentType _fromMagicBytes(Uint8List bytes) {
    if (_startsWith(bytes, _pdfMagic)) return DocumentType.pdf;
    if (_startsWith(bytes, _zipMagic)) {
      // ZIP-based: could be DOCX, PPTX, XLSX or ODT
      // Return docx as the safest default for ZIP without extension.
      // Actual sub-type will be refined by the parser.
      return DocumentType.docx;
    }
    if (_startsWith(bytes, _oleMagic)) {
      // Legacy OLE2 — default to doc
      return DocumentType.doc;
    }
    if (_startsWith(bytes, _rtfMagic)) return DocumentType.rtf;
    return DocumentType.unsupported;
  }

  static bool _startsWith(Uint8List bytes, List<int> magic) {
    if (bytes.length < magic.length) return false;
    for (int i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return true;
  }
}
