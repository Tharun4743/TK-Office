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
