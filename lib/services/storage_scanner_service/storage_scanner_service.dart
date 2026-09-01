import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../../models/file_info.dart';
import '../../storage/indexed_files_dao.dart';
import '../../utils/file_utils.dart';

class ScanProgress {
  final int totalFiles;
  final int pdfCount;
  final int docsCount;
  final int sheetsCount;
  final int slidesCount;
  final int imagesCount;
  final String currentFolder;
  final bool isFinished;

  ScanProgress({
    this.totalFiles = 0,
    this.pdfCount = 0,
    this.docsCount = 0,
    this.sheetsCount = 0,
    this.slidesCount = 0,
    this.imagesCount = 0,
    this.currentFolder = '',
    this.isFinished = false,
  });
}

class StorageScannerService {
  static const MethodChannel _storageChannel = MethodChannel('com.tk.tk_office/storage');
  final IndexedFilesDao _indexedFilesDao = IndexedFilesDao();

  final StreamController<ScanProgress> _progressController = StreamController<ScanProgress>.broadcast();
  Stream<ScanProgress> get progressStream => _progressController.stream;

  static const List<String> supportedExtensions = [
    '.pdf',
    '.doc',
    '.docx',
    '.odt',
    '.txt',
    '.rtf',
    '.xls',
    '.xlsx',
    '.ods',
    '.csv',
    '.ppt',
    '.pptx',
    '.odp',
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  ];

  static Future<bool> checkStoragePermission() async {
    try {
      final granted = await _storageChannel.invokeMethod<bool>('checkStoragePermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestStoragePermission() async {
    try {
      await _storageChannel.invokeMethod('requestStoragePermission');
    } catch (_) {}
  }

  static Future<String?> getRootStoragePath() async {
    try {
      return await _storageChannel.invokeMethod<String>('getRootStoragePath');
    } catch (_) {
      return '/storage/emulated/0';
    }
  }

  static Future<List<Map<String, String>>> getAccessibleFolders() async {
    try {
      final List<dynamic>? list = await _storageChannel.invokeMethod('getAccessibleFolders');
      if (list != null) {
        return list.map((item) => Map<String, String>.from(item as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<int> scanSharedStorage() async {
    final rootPath = await getRootStoragePath() ?? '/storage/emulated/0';
    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) return 0;

    int total = 0;
    int pdf = 0;
    int docs = 0;
    int sheets = 0;
    int slides = 0;
    int images = 0;

    final List<LocalFileInfo> batch = [];

    // Priority targets first for instant discovery
    final priorityPaths = [
      p.join(rootPath, 'Download'),
      p.join(rootPath, 'Documents'),
      p.join(rootPath, 'Android', 'media', 'com.whatsapp', 'WhatsApp', 'Media', 'WhatsApp Documents'),
      p.join(rootPath, 'WhatsApp', 'Media', 'WhatsApp Documents'),
      p.join(rootPath, 'Pictures'),
      p.join(rootPath, 'DCIM'),
    ];

    final Set<String> scannedPaths = {};

    for (final priorityPath in priorityPaths) {
      final dir = Directory(priorityPath);
      if (await dir.exists()) {
        _progressController.add(ScanProgress(
          totalFiles: total,
          pdfCount: pdf,
          docsCount: docs,
          sheetsCount: sheets,
          slidesCount: slides,
          imagesCount: images,
          currentFolder: p.basename(priorityPath),
          isFinished: false,
        ));

        await _scanDirectory(
          dir,
          batch,
          scannedPaths,
          onFileFound: (cat) {
            total++;
            switch (cat) {
              case DocumentCategory.pdf:
                pdf++;
                break;
              case DocumentCategory.document:
                docs++;
                break;
              case DocumentCategory.spreadsheet:
                sheets++;
                break;
              case DocumentCategory.presentation:
                slides++;
                break;
              case DocumentCategory.other:
                images++;
                break;
            }
          },
        );
      }
    }

    // Now scan top-level phone directories (skipping Android/data and Android/obb)
    try {
      final entities = rootDir.listSync(followLinks: false);
      for (final entity in entities) {
        if (entity is Directory) {
          final dirName = p.basename(entity.path);
          if (dirName.startsWith('.') || dirName == 'Android') continue;
          if (scannedPaths.contains(entity.path)) continue;

          _progressController.add(ScanProgress(
            totalFiles: total,
            pdfCount: pdf,
            docsCount: docs,
            sheetsCount: sheets,
            slidesCount: slides,
            imagesCount: images,
            currentFolder: dirName,
            isFinished: false,
          ));

          await _scanDirectory(
            entity,
            batch,
            scannedPaths,
            maxDepth: 3,
            onFileFound: (cat) {
              total++;
              switch (cat) {
                case DocumentCategory.pdf:
                  pdf++;
                  break;
                case DocumentCategory.document:
                  docs++;
                  break;
                case DocumentCategory.spreadsheet:
                  sheets++;
                  break;
                case DocumentCategory.presentation:
                  slides++;
                  break;
                case DocumentCategory.other:
                  images++;
                  break;
              }
            },
          );
        }
      }
    } catch (_) {}

    // Save batch into SQLite
    if (batch.isNotEmpty) {
      await _indexedFilesDao.batchInsertOrUpdate(batch);
    }

    _progressController.add(ScanProgress(
      totalFiles: total,
      pdfCount: pdf,
      docsCount: docs,
      sheetsCount: sheets,
      slidesCount: slides,
      imagesCount: images,
      currentFolder: 'Finished',
      isFinished: true,
    ));

    return total;
  }

  Future<void> _scanDirectory(
    Directory dir,
    List<LocalFileInfo> batch,
    Set<String> scannedPaths, {
    int maxDepth = 4,
    int currentDepth = 0,
    required Function(DocumentCategory) onFileFound,
  }) async {
    if (currentDepth > maxDepth) return;
    if (scannedPaths.contains(dir.path)) return;
    scannedPaths.add(dir.path);

    try {
      final entities = dir.listSync(followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (supportedExtensions.contains(ext)) {
            final stat = entity.statSync();
            final cat = FileUtils.getCategory(entity.path);
            final folderName = p.basename(p.dirname(entity.path));

            final fileInfo = LocalFileInfo(
              path: entity.path,
              name: p.basename(entity.path),
              extension: ext,
              sizeInBytes: stat.size,
              modifiedDate: stat.modified,
              category: cat,
              folderName: folderName,
            );

            batch.add(fileInfo);
            onFileFound(cat);

            if (batch.length >= 100) {
              await _indexedFilesDao.batchInsertOrUpdate(batch);
              batch.clear();
            }
          }
        } else if (entity is Directory) {
          final name = p.basename(entity.path);
          if (!name.startsWith('.')) {
            await _scanDirectory(
              entity,
              batch,
              scannedPaths,
              maxDepth: maxDepth,
              currentDepth: currentDepth + 1,
              onFileFound: onFileFound,
            );
          }
        }
      }
    } catch (_) {}
  }
}
