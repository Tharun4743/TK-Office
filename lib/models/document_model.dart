import 'dart:convert';
import 'package:dart_quill_delta/dart_quill_delta.dart';

class OfficeDocument {
  String? filePath;
  String title;
  Delta delta;
  DateTime lastModified;
  bool isDirty;

  OfficeDocument({
    this.filePath,
    required this.title,
    required this.delta,
    required this.lastModified,
    this.isDirty = false,
  });

  factory OfficeDocument.empty({String title = 'Untitled Document'}) {
    return OfficeDocument(
      title: title,
      delta: Delta()..insert('\n'),
      lastModified: DateTime.now(),
      isDirty: false,
    );
  }

  String toJsonString() {
    return jsonEncode(delta.toJson());
  }

  factory OfficeDocument.fromJsonString(String jsonString, {String? filePath, String? title}) {
    final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
    final delta = Delta.fromJson(jsonList);
    return OfficeDocument(
      filePath: filePath,
      title: title ?? 'Document',
      delta: delta,
      lastModified: DateTime.now(),
    );
  }
}
