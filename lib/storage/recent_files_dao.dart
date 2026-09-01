import 'package:sqflite/sqflite.dart';
import '../models/recent_file.dart';
import '../utils/file_utils.dart';
import 'database_helper.dart';

class RecentFilesDao {
  Future<int> insertOrUpdate(RecentFile file) async {
    final db = await DatabaseHelper.instance.database;

    final existing = await db.query(
      'recent_files',
      where: 'path = ?',
      whereArgs: [file.path],
    );

    if (existing.isNotEmpty) {
      final isStarred = existing.first['is_starred'] as int;
      return await db.update(
        'recent_files',
        {
          'title': file.title,
          'category': file.category.name,
          'size_in_bytes': file.sizeInBytes,
          'last_opened': file.lastOpened.millisecondsSinceEpoch,
          'is_starred': isStarred,
        },
        where: 'path = ?',
        whereArgs: [file.path],
      );
    } else {
      return await db.insert(
        'recent_files',
        file.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<RecentFile>> getAllRecentFiles({DocumentCategory? category}) async {
    final db = await DatabaseHelper.instance.database;

    final List<String> whereClauses = [
      "title NOT LIKE '.trashed-%'",
      "title NOT LIKE '.%'",
      "path NOT LIKE '%.trashed-%'",
      "path NOT LIKE '%/.Trash/%'",
      "category != 'other'",
    ];
    final List<dynamic> whereArgs = [];

    if (category != null) {
      whereClauses.add('category = ?');
      whereArgs.add(category.name);
    }

    final maps = await db.query(
      'recent_files',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'last_opened DESC',
      limit: 50,
    );

    return maps.map((map) => RecentFile.fromMap(map)).toList();
  }

  Future<int> toggleStar(int id, bool isStarred) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      'recent_files',
      {'is_starred': isStarred ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(String path) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete(
      'recent_files',
      where: 'path = ?',
      whereArgs: [path],
    );
  }

  Future<int> clearAll() async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete('recent_files');
  }
}
