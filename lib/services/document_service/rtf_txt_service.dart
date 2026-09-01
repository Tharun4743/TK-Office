import 'dart:io';
import 'package:dart_quill_delta/dart_quill_delta.dart';

class RtfTxtService {
  static Future<Delta> importTxt(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return Delta()..insert('\n');
    }
    try {
      final text = await file.readAsString();
      final delta = Delta();
      delta.insert(text.endsWith('\n') ? text : '$text\n');
      return delta;
    } catch (e) {
      return Delta()..insert('Error: This document cannot be read as plain text. It may be a binary file or an unsupported format.\n');
    }
  }

  /// Strips RTF control codes and returns the plain text content.
  static Future<Delta> importRtf(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return Delta()..insert('\n');

    try {
      final raw = await file.readAsString();
      final text = _stripRtfCodes(raw);
      if (text.trim().isEmpty) {
        // Fallback: try reading raw bytes as plain text
        return await importTxt(filePath);
      }
      final delta = Delta();
      delta.insert(text.endsWith('\n') ? text : '$text\n');
      return delta;
    } catch (e) {
      return importTxt(filePath);
    }
  }

  /// Removes RTF markup and returns clean text.
  static String _stripRtfCodes(String rtf) {
    final buf = StringBuffer();
    int i = 0;
    int depth = 0; // brace depth for group tracking

    while (i < rtf.length) {
      final ch = rtf[i];

      if (ch == '{') {
        depth++;
        i++;
      } else if (ch == '}') {
        depth--;
        i++;
      } else if (ch == '\\') {
        i++; // skip backslash
        if (i >= rtf.length) break;

        final next = rtf[i];

        // Escaped special chars
        if (next == '\\' || next == '{' || next == '}') {
          if (depth == 0) buf.write(next);
          i++;
        } else if (next == '\n' || next == '\r') {
          // Paragraph break
          if (depth == 0) buf.write('\n');
          i++;
        } else if (next == '\'') {
          // Hex-encoded char like \'e9
          i++;
          if (i + 1 < rtf.length) {
            final hex = rtf.substring(i, i + 2);
            final code = int.tryParse(hex, radix: 16);
            if (code != null && depth == 0) {
              buf.writeCharCode(code);
            }
            i += 2;
          }
        } else if (next == '*') {
          // \* introduces an ignorable destination — skip entire group
          i++;
        } else {
          // Control word: read until non-letter/non-digit
          final start = i;
          while (i < rtf.length && (rtf[i].contains(RegExp(r'[a-zA-Z]')))) {
            i++;
          }
          final word = rtf.substring(start, i);
          // Skip optional numeric parameter
          if (i < rtf.length && (rtf[i] == '-' || rtf[i].contains(RegExp(r'\d')))) {
            while (i < rtf.length && (rtf[i] == '-' || rtf[i].contains(RegExp(r'\d')))) {
              i++;
            }
          }
          // Skip one trailing space (delimiter)
          if (i < rtf.length && rtf[i] == ' ') i++;

          // Paragraph/line break control words
          if ((word == 'par' || word == 'line' || word == 'pagebb') && depth == 0) {
            buf.write('\n');
          }
          if (word == 'tab' && depth == 0) {
            buf.write('\t');
          }
        }
      } else if (ch == '\n' || ch == '\r') {
        // RTF hard line breaks (rare in body) — ignore, use \par instead
        i++;
      } else {
        // Normal character
        if (depth == 0) buf.write(ch);
        i++;
      }
    }

    // Collapse 3+ newlines to 2, trim edges
    return buf.toString()
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String exportToPlainText(Delta delta) {
    final buffer = StringBuffer();
    for (final op in delta.toList()) {
      if (op.data is String) {
        buffer.write(op.data as String);
      }
    }
    return buffer.toString();
  }

  static String exportToRtf(Delta delta) {
    final buffer = StringBuffer();
    buffer.write(r'{\rtf1\ansi\deff0 {\fonttbl {\f0 Times New Roman;}}');
    buffer.write(r'\viewkind4\uc1\pard\f0\fs24 ');

    for (final op in delta.toList()) {
      final data = op.data;
      if (data is String) {
        final attrs = op.attributes ?? {};
        if (attrs['bold'] == true) buffer.write(r'\b ');
        if (attrs['italic'] == true) buffer.write(r'\i ');
        if (attrs['underline'] == true) buffer.write(r'\ul ');

        final escaped = data
            .replaceAll(r'\', r'\\')
            .replaceAll('{', r'\{')
            .replaceAll('}', r'\}')
            .replaceAll('\n', r'\par ');
        buffer.write(escaped);

        if (attrs['underline'] == true) buffer.write(r'\ulnone ');
        if (attrs['italic'] == true) buffer.write(r'\i0 ');
        if (attrs['bold'] == true) buffer.write(r'\b0 ');
      }
    }

    buffer.write(r'\par }');
    return buffer.toString();
  }
}
