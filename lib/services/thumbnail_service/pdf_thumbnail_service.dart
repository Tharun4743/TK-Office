import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as px;

/// Generates high-quality, aspect-ratio-correct PDF thumbnails from the first page.
///
/// Rendering strategy:
///  • The logical target is a 600×800 box (portrait). For landscape PDFs we
///    swap to 800×600 so text and tables remain readable.
///  • The actual page bytes are then written to disk and cached in both
///    an in-memory Map and the file system.
///  • On failure the service returns null; callers show a fallback icon.
class PdfThumbnailService {
  // ── In-memory cache: pdfPath → thumbnail file path (or null = failed)
  static final Map<String, String?> _memoryCache = {};

  // ── Lock-set to prevent concurrent render of the same PDF
  static final Set<String> _rendering = {};

  /// Returns the file path of the cached thumbnail PNG, or null on failure.
  static Future<String?> getThumbnailPath(String pdfPath) async {
    // 1. Memory cache hit
    if (_memoryCache.containsKey(pdfPath)) {
      final cached = _memoryCache[pdfPath];
      if (cached != null && File(cached).existsSync()) return cached;
      // Cached entry is stale (file deleted externally) – fall through to re-render
      _memoryCache.remove(pdfPath);
    }

    // 2. File does not exist – skip
    final file = File(pdfPath);
    if (!await file.exists()) return null;

    // 3. Prevent duplicate concurrent renders for the same path
    if (_rendering.contains(pdfPath)) {
      // Spin-wait is not Flutter-safe – just skip and let the next build pick it up
      return null;
    }

    _rendering.add(pdfPath);
    try {
      // 4. Disk cache hit
      final cacheDir = await getTemporaryDirectory();
      final thumbDir = Directory(p.join(cacheDir.path, 'pdf_thumbs'));
      if (!await thumbDir.exists()) {
        await thumbDir.create(recursive: true);
      }

      final hash = md5.convert(utf8.encode(pdfPath)).toString();
      final thumbFile = File(p.join(thumbDir.path, '$hash.png'));

      if (await thumbFile.exists() && thumbFile.statSync().size > 512) {
        _memoryCache[pdfPath] = thumbFile.path;
        return thumbFile.path;
      }

      // 5. Open PDF and render first page at high resolution
      final doc = await px.PdfDocument.openFile(pdfPath);
      if (doc.pagesCount == 0) {
        await doc.close();
        _memoryCache[pdfPath] = null;
        return null;
      }

      final page = await doc.getPage(1);

      // Determine target render dimensions while preserving aspect ratio.
      // We use a fixed longest-edge of 900 px at 1.5× DPI scale, which gives
      // crisp text on both portrait (A4 ≈ 3:4) and landscape pages.
      const longestEdgePx = 900.0;
      final pageW = page.width;    // PDF points
      final pageH = page.height;   // PDF points
      final aspectRatio = pageW / pageH;

      late final double renderW;
      late final double renderH;

      if (aspectRatio >= 1.0) {
        // Landscape
        renderW = longestEdgePx;
        renderH = longestEdgePx / aspectRatio;
      } else {
        // Portrait
        renderH = longestEdgePx;
        renderW = longestEdgePx * aspectRatio;
      }

      final pageImage = await page.render(
        width: renderW,
        height: renderH,
        format: px.PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );

      await page.close();
      await doc.close();

      if (pageImage == null || pageImage.bytes.isEmpty) {
        _memoryCache[pdfPath] = null;
        return null;
      }

      // 6. Persist thumbnail to disk
      await thumbFile.writeAsBytes(pageImage.bytes);
      _memoryCache[pdfPath] = thumbFile.path;
      return thumbFile.path;
    } catch (_) {
      _memoryCache[pdfPath] = null;
      return null;
    } finally {
      _rendering.remove(pdfPath);
    }
  }

  /// Invalidate cache entry for a given PDF (e.g. after file rename/delete).
  static void invalidate(String pdfPath) {
    _memoryCache.remove(pdfPath);
  }

  /// Clear all in-memory entries (does NOT delete disk cache).
  static void clearMemoryCache() {
    _memoryCache.clear();
  }
}
