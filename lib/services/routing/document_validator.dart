import 'dart:io';

import 'package:flutter/foundation.dart';
import 'document_type_detector.dart';

enum ValidationStatus {
  ok,
  notFound,
  empty,
  corrupt,
  permissionDenied,
  tooLarge,
}

class ValidationResult {
  final ValidationStatus status;
  final String? message;

  const ValidationResult(this.status, {this.message});

  bool get isOk => status == ValidationStatus.ok;

  String get displayMessage {
    return message ??
        switch (status) {
          ValidationStatus.ok => 'Document is valid.',
          ValidationStatus.notFound =>
            'The document file could not be found. It may have been moved or deleted.',
          ValidationStatus.empty =>
            'The document file is empty and cannot be opened.',
          ValidationStatus.corrupt =>
            'The document appears to be corrupt or is not a valid file of this type.',
          ValidationStatus.permissionDenied =>
            'TK Suite does not have permission to read this file.',
          ValidationStatus.tooLarge =>
            'This file is too large to open safely on this device.',
        };
  }
}

/// Validates a document before it is sent to any renderer.
///
/// Checks: existence, readability, non-empty, and basic signature consistency.
class DocumentValidator {
  static const int _maxFileSizeBytes = 500 * 1024 * 1024; // 500 MB safety cap

  /// Validate a real file-system path.
  /// For content:// URIs, call [validateBytes] after reading via UriResolver.
  static Future<ValidationResult> validateFile(
    String filePath,
    DocumentType type,
  ) async {
    debugPrint('[DocumentValidator] validating filePath=$filePath type=$type');

    // 1. File existence
    final file = File(filePath);
    final bool exists;
    try {
      exists = await file.exists();
    } catch (e) {
      return ValidationResult(
        ValidationStatus.permissionDenied,
        message: 'Cannot access file: $e',
      );
    }
    if (!exists) {
      return const ValidationResult(ValidationStatus.notFound);
    }

    // 2. Readability + size
    final int size;
    try {
      size = await file.length();
    } catch (e) {
      return ValidationResult(
        ValidationStatus.permissionDenied,
        message: 'Cannot read file size: $e',
      );
    }

    if (size == 0) {
      return const ValidationResult(ValidationStatus.empty);
    }

    if (size > _maxFileSizeBytes) {
      return ValidationResult(
        ValidationStatus.tooLarge,
        message:
            'File size (${(size / 1048576).toStringAsFixed(1)} MB) exceeds the 500 MB safety limit.',
      );
    }

    // 3. Magic-byte consistency
    try {
      final bytes = await _readHead(file, 8);
      if (bytes != null) {
        final result = _checkSignature(bytes, type);
        if (!result.isOk) return result;
      }
    } catch (e) {
      debugPrint('[DocumentValidator] signature check failed: $e');
      // Non-fatal — proceed
    }

    return const ValidationResult(ValidationStatus.ok);
  }

  /// Validate raw bytes (for content:// streams already read).
  static ValidationResult validateBytes(Uint8List bytes, DocumentType type) {
    if (bytes.isEmpty) {
      return const ValidationResult(ValidationStatus.empty);
    }
    if (bytes.length > _maxFileSizeBytes) {
      return ValidationResult(
        ValidationStatus.tooLarge,
        message: 'File is too large to open.',
      );
    }
    return _checkSignature(bytes, type);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static Future<Uint8List?> _readHead(File file, int n) async {
    try {
      final raf = await file.open();
      final buf = Uint8List(n);
      final read = await raf.readInto(buf);
      await raf.close();
      return read > 0 ? buf.sublist(0, read) : null;
    } catch (_) {
      return null;
    }
  }

  static ValidationResult _checkSignature(Uint8List bytes, DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        if (!_startsWith(bytes, [0x25, 0x50, 0x44, 0x46])) {
          return const ValidationResult(
            ValidationStatus.corrupt,
            message:
                'This file does not appear to be a valid PDF (missing PDF signature).',
          );
        }
        return const ValidationResult(ValidationStatus.ok);

      case DocumentType.docx:
      case DocumentType.pptx:
      case DocumentType.xlsx:
      case DocumentType.odt:
        // All these are ZIP containers (PK magic)
        if (!_startsWith(bytes, [0x50, 0x4B, 0x03, 0x04]) &&
            !_startsWith(bytes, [0x50, 0x4B, 0x05, 0x06]) &&
            !_startsWith(bytes, [0x50, 0x4B, 0x07, 0x08])) {
          return const ValidationResult(
            ValidationStatus.corrupt,
            message:
                'This file does not appear to be a valid Office Open XML package.',
          );
        }
        return const ValidationResult(ValidationStatus.ok);

      case DocumentType.doc:
      case DocumentType.xls:
      case DocumentType.ppt:
        // OLE2 signature OR ZIP (renamed OOXML)
        final isOle =
            _startsWith(bytes, [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A]);
        final isZip = _startsWith(bytes, [0x50, 0x4B, 0x03, 0x04]);
        if (!isOle && !isZip) {
          // Could still be a valid file — treat as warning, not error
          debugPrint(
              '[DocumentValidator] .doc/.xls/.ppt unexpected signature — allowing');
        }
        return const ValidationResult(ValidationStatus.ok);

      case DocumentType.rtf:
        // RTF starts with {\rtf
        if (!_startsWith(bytes, [0x7B, 0x5C, 0x72, 0x74, 0x66])) {
          // Could be plain text mislabelled as RTF — still let it through
          debugPrint(
              '[DocumentValidator] RTF signature not found — allowing as plain text');
        }
        return const ValidationResult(ValidationStatus.ok);

      case DocumentType.txt:
      case DocumentType.csv:
        // No reliable magic for plain text — just allow
        return const ValidationResult(ValidationStatus.ok);

      case DocumentType.unsupported:
        return const ValidationResult(
          ValidationStatus.corrupt,
          message: 'This file type is not supported by TK Suite.',
        );
    }
  }

  static bool _startsWith(Uint8List bytes, List<int> magic) {
    if (bytes.length < magic.length) return false;
    for (int i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return true;
  }
}
