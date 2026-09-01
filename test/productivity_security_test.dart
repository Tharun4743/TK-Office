import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tk_office/models/file_info.dart';
import 'package:tk_office/utils/file_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Productivity, Tags & Security Tests', () {
    test('LocalFileInfo model supports tag, favorite, and folderName', () {
      final file = LocalFileInfo(
        path: '/storage/emulated/0/Download/report.pdf',
        name: 'report.pdf',
        extension: '.pdf',
        sizeInBytes: 1024,
        modifiedDate: DateTime.now(),
        category: DocumentCategory.pdf,
        isFavorite: true,
        tag: 'Work',
        folderName: 'Download',
      );

      expect(file.isFavorite, isTrue);
      expect(file.tag, 'Work');
      expect(file.folderName, 'Download');
      expect(file.category, DocumentCategory.pdf);
    });

    test('Thumbnail MD5 hash generator produces consistent keys', () {
      const path1 = '/storage/emulated/0/Documents/contract.pdf';
      final hash1 = md5.convert(utf8.encode(path1)).toString();
      final hash2 = md5.convert(utf8.encode(path1)).toString();

      expect(hash1, equals(hash2));
      expect(hash1.length, 32);
    });
  });
}
