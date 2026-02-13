// firestore_service.dart - Handles Firestore cloud database operations
// Used for syncing data and storing chat messages

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/journal_entry.dart';
import '../models/chat_message.dart';
import '../models/mood_entry.dart';
import 'auth_service.dart';

class FirestoreService {
  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Auth service to get current user ID
  final AuthService _authService = AuthService();

  // Get current user ID
  String get _userId => _authService.userId;

  // ==================== JOURNAL OPERATIONS ====================

  // Get reference to user's journal collection
  CollectionReference get _journalCollection {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('journals');
  }

  // Sync a journal entry to Firestore
  Future<void> syncJournalEntry(JournalEntry entry) async {
    if (_userId.isEmpty) return; // Not logged in

    await _journalCollection.doc(entry.id).set(entry.toFirestore());
  }

  // Delete journal entry from Firestore
  Future<void> deleteJournalEntry(String id) async {
    if (_userId.isEmpty) return;

    await _journalCollection.doc(id).delete();
  }

  // Get all journal entries from Firestore
  Future<List<JournalEntry>> getAllJournalEntries() async {
    if (_userId.isEmpty) return [];

    final snapshot = await _journalCollection
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      return JournalEntry.fromFirestore(doc.data() as Map<String, dynamic>);
    }).toList();
  }

  // Sync multiple entries at once
  Future<void> syncMultipleEntries(List<JournalEntry> entries) async {
    if (_userId.isEmpty) return;

    // Use batch write for efficiency
    WriteBatch batch = _firestore.batch();

    for (var entry in entries) {
      batch.set(
        _journalCollection.doc(entry.id),
        entry.toFirestore(),
      );
    }

    await batch.commit();
  }

  // ==================== CHAT OPERATIONS ====================

  // Get reference to user's chat collection
  CollectionReference get _chatCollection {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('chats');
  }

  // Get reference to user's conversations collection
  CollectionReference get _conversationsCollection {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('conversations');
  }

  // Save a chat message
  Future<void> saveChatMessage(ChatMessage message) async {
    if (_userId.isEmpty) return;

    await _chatCollection.doc(message.id).set(message.toFirestore());
  }

  // Get all chat messages (oldest first for chat display)
  Future<List<ChatMessage>> getChatMessages() async {
    if (_userId.isEmpty) return [];

    final snapshot = await _chatCollection
        .orderBy('timestamp', descending: false) // Oldest first
        .get();

    return snapshot.docs.map((doc) {
      return ChatMessage.fromFirestore(doc.data() as Map<String, dynamic>);
    }).toList();
  }

  // Get messages for a specific conversation
  Future<List<ChatMessage>> getConversationMessages(
      String conversationId) async {
    if (_userId.isEmpty) {
      debugPrint('Firestore: Cannot get messages - user not logged in');
      return [];
    }

    try {
      debugPrint('Firestore: Loading messages for conversation $conversationId');
      final snapshot = await _chatCollection
          .where('conversationId', isEqualTo: conversationId)
          .orderBy('timestamp', descending: false)
          .get();

      debugPrint('Firestore: Found ${snapshot.docs.length} messages');
      
      return snapshot.docs.map((doc) {
        return ChatMessage.fromFirestore(doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      debugPrint('Firestore: ERROR loading messages: $e');
      rethrow; // Re-throw to let the calling code handle it
    }
  }

  // Stream messages for a specific conversation (real-time)
  Stream<List<ChatMessage>> streamConversationMessages(
      String conversationId) {
    if (_userId.isEmpty) {
      return Stream.value([]);
    }

    return _chatCollection
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ChatMessage.fromFirestore(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  // Save a conversation
  Future<void> saveConversation(ChatConversation conversation) async {
    if (_userId.isEmpty) return;

    await _conversationsCollection
        .doc(conversation.id)
        .set(conversation.toFirestore());
  }

  // Update conversation's last message info
  Future<void> updateConversationLastMessage(
    String conversationId,
    String lastMessage,
    DateTime lastMessageAt,
  ) async {
    if (_userId.isEmpty) return;

    await _conversationsCollection.doc(conversationId).update({
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt.toIso8601String(),
    });
  }

  // Update conversation title
  Future<void> updateConversationTitle(
      String conversationId, String title) async {
    if (_userId.isEmpty) return;

    await _conversationsCollection.doc(conversationId).update({
      'title': title,
    });
  }

  // Get all conversations (newest first)
  Future<List<ChatConversation>> getConversations() async {
    if (_userId.isEmpty) return [];

    final snapshot = await _conversationsCollection
        .orderBy('lastMessageAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      return ChatConversation.fromFirestore(
          doc.data() as Map<String, dynamic>);
    }).toList();
  }

  // Stream all conversations (real-time, newest first)
  Stream<List<ChatConversation>> streamConversations() {
    if (_userId.isEmpty) {
      return Stream.value([]);
    }

    return _conversationsCollection
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ChatConversation.fromFirestore(
            doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  // Delete a conversation and its messages
  Future<void> deleteConversation(String conversationId) async {
    if (_userId.isEmpty) return;

    // Delete all messages in this conversation
    final messages = await _chatCollection
        .where('conversationId', isEqualTo: conversationId)
        .get();

    WriteBatch batch = _firestore.batch();
    for (var doc in messages.docs) {
      batch.delete(doc.reference);
    }

    // Delete the conversation doc
    batch.delete(_conversationsCollection.doc(conversationId));

    await batch.commit();
  }

  // Stream chat messages (real-time updates)
  Stream<List<ChatMessage>> streamChatMessages() {
    if (_userId.isEmpty) {
      return Stream.value([]);
    }

    return _chatCollection
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ChatMessage.fromFirestore(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  // Clear all chat messages
  Future<void> clearChatHistory() async {
    if (_userId.isEmpty) return;

    final snapshot = await _chatCollection.get();

    WriteBatch batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    // Also clear conversations
    final conversations = await _conversationsCollection.get();
    for (var doc in conversations.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // Get recent chat messages (last N messages)
  Future<List<ChatMessage>> getRecentMessages(int limit) async {
    if (_userId.isEmpty) return [];

    final snapshot = await _chatCollection
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    // Reverse to get oldest first
    return snapshot.docs.map((doc) {
      return ChatMessage.fromFirestore(doc.data() as Map<String, dynamic>);
    }).toList().reversed.toList();
  }

  // ==================== MOOD OPERATIONS ====================

  // Get reference to user's mood collection
  CollectionReference get _moodCollection {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('moods');
  }

  // Save a mood entry
  Future<void> saveMoodEntry(MoodEntry entry) async {
    if (_userId.isEmpty) return;
    await _moodCollection.doc(entry.id).set(entry.toFirestore());
  }

  // Get mood entries for the last N days
  Future<List<MoodEntry>> getRecentMoodEntries(int days) async {
    if (_userId.isEmpty) return [];

    final cutoff = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final snapshot = await _moodCollection
        .where('date', isGreaterThanOrEqualTo: cutoff)
        .orderBy('date', descending: false)
        .get();

    return snapshot.docs.map((doc) {
      return MoodEntry.fromFirestore(doc.data() as Map<String, dynamic>);
    }).toList();
  }

  // Get all mood entries
  Future<List<MoodEntry>> getAllMoodEntries() async {
    if (_userId.isEmpty) return [];

    final snapshot = await _moodCollection
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      return MoodEntry.fromFirestore(doc.data() as Map<String, dynamic>);
    }).toList();
  }
}
