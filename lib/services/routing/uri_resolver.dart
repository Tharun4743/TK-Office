import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Resolves content:// URIs to local temporary files for parsers that
/// require a real file-system path.
///
/// Rules:
///  - NEVER places temp files in the user-visible Documents directory.
///  - Temp files are stored in getCacheDir()/tk_viewer_temp/.
///  - Callers MUST call [deleteTemp] when finished.
class UriResolver {
  static const MethodChannel _resolverChannel =
      MethodChannel('com.tk.tk_office/resolver');

  // ── Public API ───────────────────────────────────────────────────────────

  /// Returns true if [pathOrUri] is a content:// URI (not a file path).
  static bool isContentUri(String pathOrUri) {
    return pathOrUri.startsWith('content://');
  }

  /// Gets the human-readable display name for [pathOrUri].
  ///
  /// For file paths, returns the basename.
  /// For content:// URIs, queries OpenableColumns.DISPLAY_NAME via the
  /// native resolver channel.
  static Future<String> getDisplayName(String pathOrUri) async {
    if (!isContentUri(pathOrUri)) {
      return p.basename(pathOrUri);
    }
    try {
      final result = await _resolverChannel.invokeMethod<String>(
        'getDisplayName',
        {'uri': pathOrUri},
      );
      return result?.isNotEmpty == true ? result! : 'Document';
    } catch (e) {
      debugPrint('[UriResolver] getDisplayName failed: $e');
      return 'Document';
    }
  }

  /// Copies a content:// URI stream to a temporary local file and returns
  /// the absolute path of that file.
  ///
  /// For non-content:// paths, returns the path unchanged.
  /// Returns null on error.
  static Future<String?> resolveToLocalPath(
    String pathOrUri, {
    String? displayName,
  }) async {
    if (!isContentUri(pathOrUri)) {
      // Already a real file path
      return pathOrUri;
    }

    try {
      // Ask the native layer to copy it (using ContentResolver.openInputStream)
      final result = await _resolverChannel
          .invokeMethod<Map<dynamic, dynamic>>('resolveUri', {
        'uri': pathOrUri,
      });
      final localPath = result?['localPath'] as String?;
      debugPrint('[UriResolver] native resolved to: $localPath');
      return localPath;
    } catch (e) {
      debugPrint('[UriResolver] native channel failed: $e — trying Dart fallback');
      return await _resolveViaDartFallback(pathOrUri, displayName: displayName);
    }
  }

  /// Reads the raw bytes of [pathOrUri] without creating a persistent temp file.
  /// For content:// URIs, uses the native channel.
  /// For file paths, reads directly.
  static Future<Uint8List?> readBytes(String pathOrUri) async {
    if (!isContentUri(pathOrUri)) {
      try {
        return await File(pathOrUri).readAsBytes();
      } catch (e) {
        debugPrint('[UriResolver] readBytes file error: $e');
        return null;
      }
    }
    try {
      final result = await _resolverChannel.invokeMethod<Uint8List>(
        'readUriBytes',
        {'uri': pathOrUri},
      );
      return result;
    } catch (e) {
      debugPrint('[UriResolver] readUriBytes native error: $e');
      return null;
    }
  }

  /// Deletes a temporary file created by [resolveToLocalPath].
  /// Safe to call with non-temp paths — only deletes files inside tk_viewer_temp.
  static Future<void> deleteTemp(String? localPath) async {
    if (localPath == null) return;
    if (!localPath.contains('tk_viewer_temp') &&
        !localPath.contains('tk_working_files')) {
      return; // Safety: never delete user files
    }
    try {
      final f = File(localPath);
      if (await f.exists()) {
        await f.delete();
        debugPrint('[UriResolver] deleted temp file: $localPath');
      }
    } catch (e) {
      debugPrint('[UriResolver] deleteTemp error: $e');
    }
  }

  // ── Dart-side fallback (no native channel) ────────────────────────────

  /// Fallback used if native channel is unavailable.
  /// file_picker may have already copied the file — this handles edge cases.
  static Future<String?> _resolveViaDartFallback(
    String contentUri, {
    String? displayName,
  }) async {
    // This fallback cannot read content:// URIs from Dart (no ContentResolver access).
    // The native channel (resolveUri) must be used instead.
    // This method exists only as a documented dead-end to explain the limitation.
    debugPrint('[UriResolver] Dart fallback: content:// URIs require native '
        'ContentResolver. Returning null.');
    return null;
  }
}
