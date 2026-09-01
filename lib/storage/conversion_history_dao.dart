import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class ConversionHistoryItem {
  final int? id;
  final String sourceName;
  final String targetName;
  final String targetPath;
  final String conversionType;
  final DateTime timestamp;
  final bool isSuccess;
  final int fileSize;

  ConversionHistoryItem({
    this.id,
    required this.sourceName,
    required this.targetName,
    required this.targetPath,
    required this.conversionType,
    required this.timestamp,
    required this.isSuccess,
    required this.fileSize,
  });
}

class ConversionHistoryDao {
  static const String tableName = 'conversion_history';

  Future<void> initTable() async {
    final db = await DatabaseHelper.instance.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sourceName TEXT NOT NULL,
        targetName TEXT NOT NULL,
        targetPath TEXT NOT NULL,
        conversionType TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        isSuccess INTEGER NOT NULL,
        fileSize INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_hist_time ON $tableName(timestamp DESC)');
  }

  Future<void> recordConversion(ConversionHistoryItem item) async {
    final db = await DatabaseHelper.instance.database;
    await initTable();
    await db.insert(tableName, {
      'sourceName': item.sourceName,
      'targetName': item.targetName,
      'targetPath': item.targetPath,
      'conversionType': item.conversionType,
      'timestamp': item.timestamp.millisecondsSinceEpoch,
      'isSuccess': item.isSuccess ? 1 : 0,
      'fileSize': item.fileSize,
    });
  }

  Future<List<ConversionHistoryItem>> getAllHistory() async {
    final db = await DatabaseHelper.instance.database;
    await initTable();
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      orderBy: 'timestamp DESC',
      limit: 100,
    );

    return maps.map((m) {
      return ConversionHistoryItem(
        id: m['id'] as int?,
        sourceName: m['sourceName'] as String,
        targetName: m['targetName'] as String,
        targetPath: m['targetPath'] as String,
        conversionType: m['conversionType'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(m['timestamp'] as int),
        isSuccess: (m['isSuccess'] as int) == 1,
        fileSize: m['fileSize'] as int,
      );
    }).toList();
  }

  Future<void> deleteHistoryItem(int id) async {
    final db = await DatabaseHelper.instance.database;
    await initTable();
    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearHistory() async {
    final db = await DatabaseHelper.instance.database;
    await initTable();
    await db.delete(tableName);
  }
}
