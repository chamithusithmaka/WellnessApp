// database_service.dart - Handles SQLite local database operations
// Used for offline storage of journal entries, chat messages & conversations

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/journal_entry.dart';
import '../models/chat_message.dart';

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
      version: 3,
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

    // Create chat messages table (offline-first)
    await db.execute('''
      CREATE TABLE chat_messages(
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        sender TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        conversationId TEXT NOT NULL,
        isSynced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create conversations table (offline-first)
    await db.execute('''
      CREATE TABLE chat_conversations(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        lastMessageAt TEXT NOT NULL,
        lastMessage TEXT DEFAULT '',
        isSynced INTEGER NOT NULL DEFAULT 0
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
    if (oldVersion < 3) {
      // Add chat tables for offline-first support
      await db.execute('''
        CREATE TABLE IF NOT EXISTS chat_messages(
          id TEXT PRIMARY KEY,
          text TEXT NOT NULL,
          sender TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          conversationId TEXT NOT NULL,
          isSynced INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS chat_conversations(
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          createdAt TEXT NOT NULL,
          lastMessageAt TEXT NOT NULL,
          lastMessage TEXT DEFAULT '',
          isSynced INTEGER NOT NULL DEFAULT 0
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

  // ==================== CHAT MESSAGE OPERATIONS (offline-first) ====================

  // Save a chat message locally
  Future<void> saveChatMessage(ChatMessage message, {bool isSynced = false}) async {
    final db = await database;
    await db.insert(
      'chat_messages',
      {
        'id': message.id,
        'text': message.text,
        'sender': message.sender,
        'timestamp': message.timestamp.toIso8601String(),
        'conversationId': message.conversationId,
        'isSynced': isSynced ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get messages for a conversation (oldest first)
  Future<List<ChatMessage>> getConversationMessages(String conversationId) async {
    final db = await database;
    final maps = await db.query(
      'chat_messages',
      where: 'conversationId = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => ChatMessage.fromFirestore(m)).toList();
  }

  // Get all unsynced chat messages
  Future<List<ChatMessage>> getUnsyncedMessages() async {
    final db = await database;
    final maps = await db.query(
      'chat_messages',
      where: 'isSynced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => ChatMessage.fromFirestore(m)).toList();
  }

  // Mark a chat message as synced
  Future<void> markMessageSynced(String id) async {
    final db = await database;
    await db.update(
      'chat_messages',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete messages for a conversation
  Future<void> deleteConversationMessages(String conversationId) async {
    final db = await database;
    await db.delete(
      'chat_messages',
      where: 'conversationId = ?',
      whereArgs: [conversationId],
    );
  }

  // ==================== CONVERSATION OPERATIONS (offline-first) ====================

  // Save a conversation locally
  Future<void> saveConversation(ChatConversation conversation, {bool isSynced = false}) async {
    final db = await database;
    await db.insert(
      'chat_conversations',
      {
        'id': conversation.id,
        'title': conversation.title,
        'createdAt': conversation.createdAt.toIso8601String(),
        'lastMessageAt': conversation.lastMessageAt.toIso8601String(),
        'lastMessage': conversation.lastMessage,
        'isSynced': isSynced ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all conversations (newest first)
  Future<List<ChatConversation>> getConversations() async {
    final db = await database;
    final maps = await db.query(
      'chat_conversations',
      orderBy: 'lastMessageAt DESC',
    );
    return maps.map((m) => ChatConversation.fromFirestore(m)).toList();
  }

  // Update conversation last message locally
  Future<void> updateConversationLastMessage(
    String conversationId,
    String lastMessage,
    DateTime lastMessageAt,
  ) async {
    final db = await database;
    await db.update(
      'chat_conversations',
      {
        'lastMessage': lastMessage,
        'lastMessageAt': lastMessageAt.toIso8601String(),
        'isSynced': 0, // Mark as needing sync
      },
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  // Update conversation title locally
  Future<void> updateConversationTitle(String conversationId, String title) async {
    final db = await database;
    await db.update(
      'chat_conversations',
      {
        'title': title,
        'isSynced': 0,
      },
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  // Get all unsynced conversations
  Future<List<ChatConversation>> getUnsyncedConversations() async {
    final db = await database;
    final maps = await db.query(
      'chat_conversations',
      where: 'isSynced = ?',
      whereArgs: [0],
    );
    return maps.map((m) => ChatConversation.fromFirestore(m)).toList();
  }

  // Mark a conversation as synced
  Future<void> markConversationSynced(String id) async {
    final db = await database;
    await db.update(
      'chat_conversations',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete a conversation locally
  Future<void> deleteConversation(String conversationId) async {
    final db = await database;
    await db.delete('chat_messages', where: 'conversationId = ?', whereArgs: [conversationId]);
    await db.delete('chat_conversations', where: 'id = ?', whereArgs: [conversationId]);
  }
}
