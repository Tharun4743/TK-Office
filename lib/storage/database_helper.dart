import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tk_office.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Recent Files Table
    await db.execute('''
      CREATE TABLE recent_files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        size_in_bytes INTEGER NOT NULL,
        last_opened INTEGER NOT NULL,
        is_starred INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Document Recovery Table (for crash recovery)
    await db.execute('''
      CREATE TABLE recovery_documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_path TEXT,
        recovery_path TEXT NOT NULL,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        last_saved INTEGER NOT NULL
      )
    ''');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
