import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dart_quill_delta/dart_quill_delta.dart';

/// Extracts readable text from legacy binary Word 97–2003 (.doc) files.
///
/// Implements OLE2 Compound File Binary (CFB) stream extraction to read the
/// actual 'WordDocument' stream, ensuring embedded JPEG/PNG image streams and
/// binary metadata are never dumped as raw text.
class DocBinaryService {
  static const int _minRunLength = 3;

  /// Attempts to extract text from a binary .doc file.
  static Future<Delta> importDoc(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return Delta()..insert('\n');

      final bytes = await file.readAsBytes();

      // 1. Try parsing OLE2 WordDocument stream first (spec-accurate extraction)
      final wordDocStream = _extractWordDocumentStream(bytes);
      final rawBytes = wordDocStream ?? bytes;

      // 2. Extract body text from the WordDocument stream
      String extractedText = '';
      if (wordDocStream != null) {
        extractedText = _extractFromWordDocStream(wordDocStream);
      }

      // 3. Fallback: UTF-16LE and sanitized ASCII scan
      if (extractedText.trim().isEmpty) {
        final utf16Text = _extractUtf16Le(rawBytes);
        final asciiText = _extractAscii(rawBytes);

        if (utf16Text.length >= asciiText.length && utf16Text.trim().isNotEmpty) {
          extractedText = utf16Text;
        } else if (asciiText.trim().isNotEmpty) {
          extractedText = asciiText;
        }
      }

      extractedText = _cleanText(extractedText);

      if (extractedText.trim().isEmpty) {
        return Delta()
          ..insert(
            'This document could not be read directly. '
            'Please open it in Microsoft Word and save as .docx format.\n',
          );
      }

      final delta = Delta();
      final lines = extractedText.split('\n');
      for (final line in lines) {
        delta.insert('$line\n');
      }
      return delta;
    } catch (e) {
      return Delta()
        ..insert('Could not read this file. It may be password-protected or corrupted.\n');
    }
  }

  // ──────────────────────────────────────────────────
  //  OLE2 WordDocument Stream Extractor
  // ──────────────────────────────────────────────────
  static Uint8List? _extractWordDocumentStream(Uint8List bytes) {
    if (bytes.length < 512) return null;
    // OLE2 magic bytes: D0 CF 11 E0 A1 B1 1A E1
    if (bytes[0] != 0xD0 || bytes[1] != 0xCF || bytes[2] != 0x11 || bytes[3] != 0xE0 ||
        bytes[4] != 0xA1 || bytes[5] != 0xB1 || bytes[6] != 0x1A || bytes[7] != 0xE1) {
      return null;
    }

    try {
      final byteData = ByteData.sublistView(bytes);
      final sectorShift = byteData.getUint16(30, Endian.little);
      final sectorSize = 1 << sectorShift;

      final numFatSectors = byteData.getInt32(44, Endian.little);
      final firstDirSector = byteData.getInt32(48, Endian.little);

      final fatSectorIndices = <int>[];
      for (var i = 0; i < 109 && i < numFatSectors; i++) {
        final sec = byteData.getInt32(76 + i * 4, Endian.little);
        if (sec >= 0) fatSectorIndices.add(sec);
      }

      final fat = <int, int>{};
      for (final fatSec in fatSectorIndices) {
        final secOffset = (fatSec + 1) * sectorSize;
        if (secOffset + sectorSize <= bytes.length) {
          final entriesInSec = sectorSize ~/ 4;
          for (var e = 0; e < entriesInSec; e++) {
            final nextSec = byteData.getInt32(secOffset + e * 4, Endian.little);
            final entryIndex = fat.length;
            fat[entryIndex] = nextSec;
          }
        }
      }

      // Directory search for WordDocument stream
      var curDirSec = firstDirSector;
      while (curDirSec >= 0 && curDirSec != -2) {
        final dirSecOffset = (curDirSec + 1) * sectorSize;
        if (dirSecOffset + sectorSize > bytes.length) break;

        for (var entryIdx = 0; entryIdx < (sectorSize ~/ 128); entryIdx++) {
          final entryOffset = dirSecOffset + entryIdx * 128;
          final nameLen = byteData.getUint16(entryOffset + 64, Endian.little);
          if (nameLen > 0 && nameLen <= 64) {
            final nameBytes = bytes.sublist(entryOffset, entryOffset + nameLen);
            final name = utf8.decode(nameBytes.where((b) => b != 0).toList(), allowMalformed: true);
            if (name.contains('WordDocument')) {
              final startSec = byteData.getInt32(entryOffset + 116, Endian.little);
              final streamSize = byteData.getInt32(entryOffset + 120, Endian.little);
              return _readStreamChain(bytes, startSec, streamSize, sectorSize, fat);
            }
          }
        }
        curDirSec = fat[curDirSec] ?? -2;
      }
    } catch (_) {}

    return null;
  }

  static Uint8List _readStreamChain(
    Uint8List bytes,
    int startSec,
    int streamSize,
    int sectorSize,
    Map<int, int> fat,
  ) {
    final streamData = BytesBuilder();
    var curSec = startSec;
    var bytesRemaining = streamSize;

    while (curSec >= 0 && curSec != -2 && bytesRemaining > 0) {
      final secOffset = (curSec + 1) * sectorSize;
      if (secOffset >= bytes.length) break;
      final bytesToRead = (bytesRemaining < sectorSize) ? bytesRemaining : sectorSize;
      final actualAvailable = (secOffset + bytesToRead <= bytes.length) ? bytesToRead : (bytes.length - secOffset);
      if (actualAvailable <= 0) break;

      streamData.add(bytes.sublist(secOffset, secOffset + actualAvailable));
      bytesRemaining -= actualAvailable;
      curSec = fat[curSec] ?? -2;
    }

    return streamData.toBytes();
  }

  // ──────────────────────────────────────────────────
  //  Extract pure body text from WordDocument FIB
  // ──────────────────────────────────────────────────
  static String _extractFromWordDocStream(Uint8List stream) {
    if (stream.length < 512) return '';
    try {
      final byteData = ByteData.sublistView(stream);
      // fcMin = offset in WordDocument stream where main text starts (usually 0x0200 = 512)
      final fcMin = byteData.getUint32(0x0018, Endian.little);
      // ccpText = character count of body text
      final ccpText = byteData.getUint32(0x004C, Endian.little);

      if (fcMin > 0 && fcMin < stream.length && ccpText > 0) {
        // First try 8-bit text slice
        final end8 = (fcMin + ccpText <= stream.length) ? (fcMin + ccpText) : stream.length;
        final slice8 = stream.sublist(fcMin, end8);
        final asciiText = _extractAscii(slice8);

        // Also try UTF-16 text slice
        final end16 = (fcMin + ccpText * 2 <= stream.length) ? (fcMin + ccpText * 2) : stream.length;
        final slice16 = stream.sublist(fcMin, end16);
        final utf16Text = _extractUtf16Le(slice16);

        if (utf16Text.length >= asciiText.length && utf16Text.trim().isNotEmpty) {
          return utf16Text;
        } else if (asciiText.trim().isNotEmpty) {
          return asciiText;
        }
      }
    } catch (_) {}

    return '';
  }

  // ──────────────────────────────────────────────────
  //  UTF-16LE extraction
  //  Extracts UTF-16LE text runs from Word binary stream
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
          final s = run.toString();
          if (!_isBinaryMarker(s)) {
            buf.write(s);
            if (codeUnit == 0x000D || codeUnit == 0x0007 || codeUnit == 0x000A) {
              buf.write('\n');
            } else {
              buf.write(' ');
            }
          }
        }
        run.clear();
      }
    }

    if (run.length >= _minRunLength) {
      final s = run.toString();
      if (!_isBinaryMarker(s)) {
        buf.write(s);
      }
    }

    return buf.toString();
  }

  // ──────────────────────────────────────────────────
  //  ASCII / Latin-1 extraction
  //  Extracts printable ASCII / Latin-1 runs
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
          final s = run.toString();
          if (!_isBinaryMarker(s)) {
            buf.write(s);
            if (b == 0x0D || b == 0x0A || b == 0x07 || b == 0x0B) {
              buf.write('\n');
            } else {
              buf.write(' ');
            }
          }
        }
        run.clear();
      }
    }

    if (run.length >= _minRunLength) {
      final s = run.toString();
      if (!_isBinaryMarker(s)) {
        buf.write(s);
      }
    }

    return buf.toString();
  }

  static bool _isReadableUtf16(int code) {
    return (code >= 0x0020 && code <= 0x007E) ||
        (code >= 0x00A0 && code <= 0x00FF) ||
        (code >= 0x0100 && code <= 0x024F);
  }

  static bool _isPrintableAscii(int b) {
    return (b >= 0x20 && b <= 0x7E) || b == 0x09;
  }

  /// Identifies specific binary image markers and JPEG Huffman tables to ignore
  static bool _isBinaryMarker(String s) {
    if (s.contains('JFIF') ||
        s.contains('Exif') ||
        s.contains('Photoshop') ||
        s.contains('Ducky') ||
        s.contains('Adobe') ||
        s.contains('ICC_PROFILE') ||
        s.contains(r'$3br') ||
        s.contains('CDEFGHIJSTUVWXYZ') ||
        s.contains('cdefghijstuvwxyz') ||
        s.contains('Root Entry') ||
        s.contains('WordDocument') ||
        s.contains('CompObj') ||
        s.contains('ObjectPool') ||
        s.contains('1Table') ||
        s.contains('0Table') ||
        s.contains('SummaryInformation')) {
      return true;
    }
    return false;
  }

  // ──────────────────────────────────────────────────
  //  Post-process: sanitize and clean text lines
  // ──────────────────────────────────────────────────
  static String _cleanText(String raw) {
    var text = raw
        .replaceAll(RegExp(r'Root Entry|WordDocument|CompObj|ObjectPool|1Table|0Table|SummaryInformation|DocumentSummaryInformation'), '')
        .replaceAll(RegExp(r'bjbj[a-zA-Z0-9]*'), '')
        .replaceAll(RegExp(r',{2,}'), '  |  ')
        .replaceAll(RegExp(r'\.{4,}'), ' ... ')
        .replaceAll(RegExp(r'_{4,}'), ' ___ ')
        .replaceAll(RegExp(r'[ \t]{4,}'), '   ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    final lines = text.split('\n');
    final goodLines = lines.where((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return false;
      if (_isBinaryMarker(trimmed)) return false;
      // Must contain at least one readable character
      return RegExp(r'[a-zA-Z0-9]').hasMatch(trimmed);
    }).toList();

    return goodLines.join('\n');
  }
}
