import 'package:flutter/foundation.dart';
import 'document_type_detector.dart';

/// Diagnostic logger for the document viewer pipeline.
/// All output goes to debugPrint only — never shown to the user.
class DocumentViewerLogger {
  static void logOpen({
    required String uri,
    String? displayName,
    String? mimeType,
    String? extension,
    required DocumentType detectedType,
    int? fileSizeBytes,
    String? permission,
    String? parserName,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '\n╔══ DocumentViewer ══════════════════════════╗\n'
      '║ URI         : $uri\n'
      '║ Name        : ${displayName ?? "unknown"}\n'
      '║ MIME        : ${mimeType ?? "unknown"}\n'
      '║ Extension   : ${extension ?? "unknown"}\n'
      '║ DetectedType: $detectedType\n'
      '║ FileSize    : ${fileSizeBytes != null ? "${(fileSizeBytes / 1024).toStringAsFixed(1)} KB" : "unknown"}\n'
      '║ Permission  : ${permission ?? "n/a"}\n'
      '║ Parser      : ${parserName ?? "n/a"}\n'
      '╚════════════════════════════════════════════╝',
    );
  }

  static void logRenderSuccess({
    required DocumentType type,
    required String uri,
  }) {
    if (!kDebugMode) return;
    debugPrint('[DocumentViewer] ✓ RenderStatus=SUCCESS type=$type uri=$uri');
  }

  static void logRenderError({
    required DocumentType type,
    required String uri,
    required Object exception,
    required String stage,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '\n╔══ DocumentViewer ERROR ════════════════════╗\n'
      '║ Type      : $type\n'
      '║ URI       : $uri\n'
      '║ Stage     : $stage\n'
      '║ Exception : $exception\n'
      '╚════════════════════════════════════════════╝',
    );
  }
}
