// database_service.dart - Handles SQLite local database operations
// Used for offline storage of journal entries

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/journal_entry.dart';

class DatabaseService {
  // Singleton pattern - only one instance of database
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // Database instance
  static Database? _database;

  // Get database (create if doesn't exist)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize the database
  Future<Database> _initDatabase() async {
    // Get the path to store the database
    String path = join(await getDatabasesPath(), 'wellness_app.db');

    // Open/create database
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  // Create tables when database is first created
  Future<void> _createDatabase(Database db, int version) async {
    // Create journal entries table
    await db.execute('''
      CREATE TABLE journal_entries(
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        emotion TEXT NOT NULL,
        date INTEGER NOT NULL,
        isSynced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create mood entries table
    await db.execute('''
      CREATE TABLE mood_entries(
        id TEXT PRIMARY KEY,
        mood TEXT NOT NULL,
        score INTEGER NOT NULL,
        note TEXT DEFAULT '',
        source TEXT DEFAULT 'manual',
        date INTEGER NOT NULL,
        emotionBreakdown TEXT DEFAULT ''
      )
    ''');
  }

  // Upgrade database when version changes
  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add mood_entries table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS mood_entries(
          id TEXT PRIMARY KEY,
          mood TEXT NOT NULL,
          score INTEGER NOT NULL,
          note TEXT DEFAULT '',
          source TEXT DEFAULT 'manual',
          date INTEGER NOT NULL,
          emotionBreakdown TEXT DEFAULT ''
        )
      ''');
    }
  }

  // ==================== JOURNAL ENTRY OPERATIONS ====================

  // Insert a new journal entry
  Future<void> insertJournalEntry(JournalEntry entry) async {
    final db = await database;
    await db.insert(
      'journal_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace, // Replace if exists
    );
  }

  // Get all journal entries (newest first)
  Future<List<JournalEntry>> getAllJournalEntries() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'journal_entries',
      orderBy: 'date DESC', // Newest first
    );

    // Convert List<Map> to List<JournalEntry>
    return List.generate(maps.length, (i) {
      return JournalEntry.fromMap(maps[i]);
    });
  }

  // Get a single journal entry by ID
  Future<JournalEntry?> getJournalEntry(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'journal_entries',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return JournalEntry.fromMap(maps.first);
  }

  // Update an existing journal entry
  Future<void> updateJournalEntry(JournalEntry entry) async {
    final db = await database;
    await db.update(
      'journal_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  // Delete a journal entry
  Future<void> deleteJournalEntry(String id) async {
    final db = await database;
    await db.delete(
      'journal_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get all unsynced entries (for syncing to Firestore)
  Future<List<JournalEntry>> getUnsyncedEntries() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'journal_entries',
      where: 'isSynced = ?',
      whereArgs: [0],
    );

    return List.generate(maps.length, (i) {
      return JournalEntry.fromMap(maps[i]);
    });
  }

  // Mark entry as synced
  Future<void> markAsSynced(String id) async {
    final db = await database;
    await db.update(
      'journal_entries',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get entries by emotion (for mood analytics)
  Future<List<JournalEntry>> getEntriesByEmotion(String emotion) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'journal_entries',
      where: 'emotion = ?',
      whereArgs: [emotion],
    );

    return List.generate(maps.length, (i) {
      return JournalEntry.fromMap(maps[i]);
    });
  }

  // Get emotion counts for chart (returns map of emotion -> count)
  Future<Map<String, int>> getEmotionCounts() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT emotion, COUNT(*) as count 
      FROM journal_entries 
      GROUP BY emotion
    ''');

    Map<String, int> counts = {};
    for (var row in results) {
      counts[row['emotion'] as String] = row['count'] as int;
    }
    return counts;
  }

  // Get entries from last N days
  Future<List<JournalEntry>> getRecentEntries(int days) async {
    final db = await database;
    final cutoffDate = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;

    final List<Map<String, dynamic>> maps = await db.query(
      'journal_entries',
      where: 'date >= ?',
      whereArgs: [cutoffDate],
      orderBy: 'date DESC',
    );

    return List.generate(maps.length, (i) {
      return JournalEntry.fromMap(maps[i]);
    });
  }
}
