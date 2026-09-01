import 'dart:io';
import 'dart:typed_data';
import 'package:dart_quill_delta/dart_quill_delta.dart';

/// Extracts readable text from legacy binary Word 97–2003 (.doc) files.
///
/// The .doc format is OLE2 Compound Document. Without a full OLE2 parser
/// (unavailable in pure Dart), the best approach is a well-known heuristic:
/// scan the raw byte stream for UTF-16LE text runs (how Word stores body text)
/// and fall back to ASCII extraction. This is how many mobile office apps work.
class DocBinaryService {
  /// Minimum run length — ignore noise below this many chars.
  static const int _minRunLength = 3;

  /// Attempts to extract text from a binary .doc file.
  /// Returns a Delta with the extracted text, or a helpful message if
  /// no text could be found.
  static Future<Delta> importDoc(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return Delta()..insert('\n');

      final bytes = await file.readAsBytes();

      // 1. First try: UTF-16LE extraction (primary Word storage)
      final utf16Text = _extractUtf16Le(bytes);

      // 2. Fallback: ASCII/Latin-1 extraction
      final asciiText = _extractAscii(bytes);

      // Pick the best result (prefer UTF-16 if it has more readable content)
      String bestText;
      if (utf16Text.length >= asciiText.length && utf16Text.trim().isNotEmpty) {
        bestText = utf16Text;
      } else if (asciiText.trim().isNotEmpty) {
        bestText = asciiText;
      } else {
        bestText = '';
      }

      bestText = _cleanText(bestText);

      if (bestText.trim().isEmpty) {
        // File exists but we couldn't extract readable text — it may be
        // heavily encrypted or a corrupt file.
        return Delta()
          ..insert(
            'This file appears to be encrypted or uses an unsupported '
            'Word format. Try opening it in Microsoft Word and saving as .docx.\n',
          );
      }

      // Build a Delta from the extracted paragraphs
      final delta = Delta();
      final lines = bestText.split('\n');
      for (final line in lines) {
        delta.insert('$line\n');
      }
      return delta;
    } catch (e) {
      // Absolute last resort — never crash
      return Delta()
        ..insert('Could not read this file. It may be password-protected or corrupted.\n');
    }
  }

  // ──────────────────────────────────────────────────
  //  UTF-16LE extraction
  //  Word 97-2003 stores the main body text as UTF-16LE
  //  in a specific stream, but scanning for runs still
  //  yields readable content in most cases.
  // ──────────────────────────────────────────────────
  static String _extractUtf16Le(Uint8List bytes) {
    final buf = StringBuffer();
    final run = StringBuffer();

    for (var i = 0; i < bytes.length - 1; i += 2) {
      final lo = bytes[i];
      final hi = bytes[i + 1];
      final codeUnit = lo | (hi << 8);

      if (_isReadableUtf16(codeUnit)) {
        run.writeCharCode(codeUnit);
      } else {
        if (run.length >= _minRunLength) {
          buf.write(run.toString());
          // Add newline between separated runs to preserve paragraph breaks
          if (codeUnit == 0x000D || codeUnit == 0x0007) {
            buf.write('\n');
          } else {
            buf.write(' ');
          }
        }
        run.clear();
      }
    }
    // Flush last run
    if (run.length >= _minRunLength) {
      buf.write(run.toString());
    }

    return buf.toString();
  }

  // ──────────────────────────────────────────────────
  //  ASCII / Latin-1 extraction
  //  Scans byte-by-byte for printable ASCII runs.
  // ──────────────────────────────────────────────────
  static String _extractAscii(Uint8List bytes) {
    final buf = StringBuffer();
    final run = StringBuffer();

    for (var i = 0; i < bytes.length; i++) {
      final b = bytes[i];

      if (_isPrintableAscii(b)) {
        run.writeCharCode(b);
      } else {
        if (run.length >= _minRunLength) {
          buf.write(run.toString());
          if (b == 0x0D || b == 0x0A) {
            buf.write('\n');
          } else {
            buf.write(' ');
          }
        }
        run.clear();
      }
    }
    if (run.length >= _minRunLength) {
      buf.write(run.toString());
    }

    return buf.toString();
  }

  static bool _isReadableUtf16(int code) {
    // Printable Basic Latin, Latin-1, common punctuation
    return (code >= 0x0020 && code <= 0x007E) || // ASCII printable
        (code >= 0x00A0 && code <= 0x00FF) || // Latin-1 supplement
        (code >= 0x0100 && code <= 0x024F) || // Latin Extended
        code == 0x000A || // LF
        code == 0x000D || // CR
        code == 0x0009;   // Tab
  }

  static bool _isPrintableAscii(int b) {
    return (b >= 0x20 && b <= 0x7E) || b == 0x09 || b == 0x0A || b == 0x0D;
  }

  // ──────────────────────────────────────────────────
  //  Post-process: remove common OLE2 / binary noise
  // ──────────────────────────────────────────────────
  static String _cleanText(String raw) {
    // Remove lone isolated characters (common binary noise)
    // Remove consecutive spaces > 3
    var text = raw
        .replaceAll(RegExp(r'[ \t]{4,}'), '   ')
        // Collapse 3+ consecutive newlines to 2
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        // Remove OLE header strings
        .replaceAll(RegExp(r'Root Entry|WordDocument|CompObj|ObjectPool|1Table|0Table'), '')
        // Remove short isolated tokens that are clearly binary noise
        .replaceAll(RegExp(r'\b\w{1,2}\b[ \t]*'), '')
        .trim();

    // Final filter: only keep lines that have at least one real word (3+ chars)
    final lines = text.split('\n');
    final goodLines = lines.where((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return true; // keep blank separators
      return RegExp(r'[a-zA-Z\u00C0-\u024F]{3,}').hasMatch(trimmed);
    }).toList();

    return goodLines.join('\n');
  }
}
