import 'package:sqflite/sqflite.dart';
import '../models/file_info.dart';
import '../utils/file_utils.dart';
import 'database_helper.dart';

class IndexedFilesDao {
  static const String tableName = 'indexed_files';

  Future<void> initTable() async {
    final db = await DatabaseHelper.instance.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        path TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        extension TEXT NOT NULL,
        sizeInBytes INTEGER NOT NULL,
        modifiedDate INTEGER NOT NULL,
        category TEXT NOT NULL,
        folder TEXT NOT NULL,
        isFavorite INTEGER DEFAULT 0,
        tag TEXT DEFAULT NULL
      )
    ''');
    try {
      await db.execute('ALTER TABLE $tableName ADD COLUMN tag TEXT DEFAULT NULL');
    } catch (_) {}
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cat ON $tableName(category)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_fav ON $tableName(isFavorite)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tag ON $tableName(tag)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mod ON $tableName(modifiedDate DESC)');

    // Purge any previously indexed image files or trashed files from SQLite
    try {
      final imagePlaceholders = FileUtils.imageExtensions.map((e) => "'$e'").join(',');
      await db.execute('''
        DELETE FROM $tableName 
        WHERE LOWER(extension) IN ($imagePlaceholders) 
           OR name LIKE '.trashed-%' 
           OR name LIKE '.%' 
           OR path LIKE '%.trashed-%' 
           OR path LIKE '%/.Trash/%' 
           OR path LIKE '%\\\\.trash\\\\%' 
           OR path LIKE '%\\\\.trashed%' 
           OR category = 'other'
      ''');
    } catch (_) {}
  }

  Future<void> batchInsertOrUpdate(List<LocalFileInfo> files) async {
    final db = await DatabaseHelper.instance.database;
    await initTable();
    final batch = db.batch();

    for (final file in files) {
      final ext = file.extension.toLowerCase();
      final name = file.name.toLowerCase();
      final path = file.path.toLowerCase();

      // Strictly ignore images, trashed files, hidden files, and unsupported categories
      if (name.startsWith('.') ||
          name.startsWith('.trashed-') ||
          path.contains('/.trash/') ||
          path.contains('/.trashed') ||
          path.contains('\\.trash\\') ||
          path.contains('\\.trashed')) {
        continue;
      }
      if (FileUtils.isImageFile(file.path) || file.category == DocumentCategory.other) {
        continue;
      }
      if (!FileUtils.documentExtensions.contains(ext)) {
        continue;
      }

      batch.insert(
        tableName,
        {
          'path': file.path,
          'name': file.name,
          'extension': file.extension,
          'sizeInBytes': file.sizeInBytes,
          'modifiedDate': file.modifiedDate.millisecondsSinceEpoch,
          'category': file.category.name,
          'folder': file.folderName ?? 'Device Storage',
          'isFavorite': file.isFavorite ? 1 : 0,
          'tag': file.tag,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<LocalFileInfo>> getAllFiles({
    DocumentCategory? category,
    String? tag,
    bool? onlyFavorites,
    String? searchQuery,
    String sortBy = 'date_desc',
  }) async {
    final db = await DatabaseHelper.instance.database;
    await initTable();

    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    // Always exclude trashed and hidden files
    whereClauses.add("name NOT LIKE '.trashed-%'");
    whereClauses.add("name NOT LIKE '.%'");
    whereClauses.add("path NOT LIKE '%.trashed-%'");
    whereClauses.add("path NOT LIKE '%/.Trash/%'");

    // Always exclude all image extensions
    final imagePlaceholders = FileUtils.imageExtensions.map((_) => '?').join(',');
    whereClauses.add("LOWER(extension) NOT IN ($imagePlaceholders)");
    whereArgs.addAll(FileUtils.imageExtensions);

    if (category != null) {
      whereClauses.add('category = ?');
      whereArgs.add(category.name);
    } else {
      // For "All Files", only query supported document categories
      whereClauses.add("category IN ('document', 'spreadsheet', 'presentation', 'pdf')");
    }

    if (tag != null && tag.isNotEmpty) {
      whereClauses.add('tag = ?');
      whereArgs.add(tag);
    }

    if (onlyFavorites == true) {
      whereClauses.add('isFavorite = 1');
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('name LIKE ?');
      whereArgs.add('%${searchQuery.trim()}%');
    }

    String orderBy = 'modifiedDate DESC';
    switch (sortBy) {
      case 'date_asc':
        orderBy = 'modifiedDate ASC';
        break;
      case 'name_asc':
        orderBy = 'name ASC';
        break;
      case 'name_desc':
        orderBy = 'name DESC';
        break;
      case 'size_desc':
        orderBy = 'sizeInBytes DESC';
        break;
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: orderBy,
      limit: 1000,
    );

    return maps.map((m) {
      final catName = m['category'] as String;
      final cat = DocumentCategory.values.firstWhere(
        (c) => c.name == catName,
        orElse: () => DocumentCategory.other,
      );

      return LocalFileInfo(
        path: m['path'] as String,
        name: m['name'] as String,
        extension: m['extension'] as String,
        sizeInBytes: m['sizeInBytes'] as int,
        modifiedDate: DateTime.fromMillisecondsSinceEpoch(m['modifiedDate'] as int),
        category: cat,
        folderName: m['folder'] as String?,
        isFavorite: (m['isFavorite'] as int? ?? 0) == 1,
        tag: m['tag'] as String?,
      );
    }).toList();
  }

  Future<List<LocalFileInfo>> getStarredFiles() async {
    return getAllFiles(onlyFavorites: true);
  }

  Future<void> toggleFavorite(String path, bool isFavorite) async {
    final db = await DatabaseHelper.instance.database;
    await initTable();
    await db.update(
      tableName,
      {'isFavorite': isFavorite ? 1 : 0},
      where: 'path = ?',
      whereArgs: [path],
    );
  }

  Future<void> updateTag(String path, String? tag) async {
    final db = await DatabaseHelper.instance.database;
    await initTable();
    await db.update(
      tableName,
      {'tag': tag},
      where: 'path = ?',
      whereArgs: [path],
    );
  }

  Future<void> batchDelete(List<String> paths) async {
    final db = await DatabaseHelper.instance.database;
    await initTable();
    final batch = db.batch();
    for (final p in paths) {
      batch.delete(tableName, where: 'path = ?', whereArgs: [p]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> batchUpdateTag(List<String> paths, String? tag) async {
    final db = await DatabaseHelper.instance.database;
    await initTable();
    final batch = db.batch();
    for (final p in paths) {
      batch.update(tableName, {'tag': tag}, where: 'path = ?', whereArgs: [p]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> batchSetFavorite(List<String> paths, bool isFavorite) async {
    final db = await DatabaseHelper.instance.database;
    await initTable();
    final batch = db.batch();
    for (final p in paths) {
      batch.update(tableName, {'isFavorite': isFavorite ? 1 : 0}, where: 'path = ?', whereArgs: [p]);
    }
    await batch.commit(noResult: true);
  }

  Future<int> countByCategory(DocumentCategory category) async {
    if (category == DocumentCategory.other) return 0;
    final db = await DatabaseHelper.instance.database;
    await initTable();
    final imagePlaceholders = FileUtils.imageExtensions.map((_) => '?').join(',');
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $tableName WHERE category = ? '
      "AND name NOT LIKE '.trashed-%' AND name NOT LIKE '.%' "
      "AND path NOT LIKE '%.trashed-%' AND path NOT LIKE '%/.Trash/%' "
      "AND LOWER(extension) NOT IN ($imagePlaceholders)",
      [category.name, ...FileUtils.imageExtensions],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTotalCount() async {
    final db = await DatabaseHelper.instance.database;
    await initTable();
    final imagePlaceholders = FileUtils.imageExtensions.map((_) => '?').join(',');
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM $tableName WHERE category IN ('document', 'spreadsheet', 'presentation', 'pdf') "
      "AND name NOT LIKE '.trashed-%' AND name NOT LIKE '.%' "
      "AND path NOT LIKE '%.trashed-%' AND path NOT LIKE '%/.Trash/%' "
      "AND LOWER(extension) NOT IN ($imagePlaceholders)",
      FileUtils.imageExtensions,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteByPath(String path) async {
    final db = await DatabaseHelper.instance.database;
    await initTable();
    await db.delete(tableName, where: 'path = ?', whereArgs: [path]);
  }

  Future<void> updatePath(String oldPath, String newPath, String newName) async {
    final db = await DatabaseHelper.instance.database;
    await initTable();
    await db.update(
      tableName,
      {'path': newPath, 'name': newName},
      where: 'path = ?',
      whereArgs: [oldPath],
    );
  }

  Future<void> clearAll() async {
    final db = await DatabaseHelper.instance.database;
    await initTable();
    await db.delete(tableName);
  }
}
