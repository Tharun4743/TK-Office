import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as px;

class PdfThumbnailService {
  static final Map<String, String?> _memoryCache = {};

  static Future<String?> getThumbnailPath(String pdfPath) async {
    if (_memoryCache.containsKey(pdfPath)) {
      final cached = _memoryCache[pdfPath];
      if (cached != null && File(cached).existsSync()) {
        return cached;
      }
    }

    final file = File(pdfPath);
    if (!await file.exists()) return null;

    try {
      final cacheDir = await getTemporaryDirectory();
      final thumbDir = Directory(p.join(cacheDir.path, 'thumbnails'));
      if (!await thumbDir.exists()) {
        await thumbDir.create(recursive: true);
      }

      final hash = md5.convert(utf8.encode(pdfPath)).toString();
      final thumbFile = File(p.join(thumbDir.path, '$hash.png'));

      if (await thumbFile.exists()) {
        _memoryCache[pdfPath] = thumbFile.path;
        return thumbFile.path;
      }

      // Render 1st page
      final doc = await px.PdfDocument.openFile(pdfPath);
      if (doc.pagesCount > 0) {
        final page = await doc.getPage(1);
        final pageImage = await page.render(
          width: 160,
          height: 220,
          format: px.PdfPageImageFormat.png,
        );
        await page.close();
        await doc.close();

        if (pageImage != null) {
          await thumbFile.writeAsBytes(pageImage.bytes);
          _memoryCache[pdfPath] = thumbFile.path;
          return thumbFile.path;
        }
      }
      await doc.close();
    } catch (_) {}

    return null;
  }
}
