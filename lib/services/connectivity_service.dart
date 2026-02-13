// connectivity_service.dart - Monitors network connectivity and syncs
// offline chat data to Firebase when the internet reconnects

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_service.dart';
import 'firestore_service.dart';
import 'auth_service.dart';

class ConnectivityService {
  // Singleton
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final DatabaseService _db = DatabaseService();
  final FirestoreService _firestore = FirestoreService();
  final AuthService _auth = AuthService();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;
  bool _isSyncing = false;

  /// Whether the device currently has internet connectivity
  bool get isOnline => _isOnline;

  /// Stream that emits true/false when connectivity changes
  final _onlineController = StreamController<bool>.broadcast();
  Stream<bool> get onlineStream => _onlineController.stream;

  /// Initialize connectivity monitoring — call once at app start
  Future<void> init() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _isOnline = _hasInternet(result);
    debugPrint('Connectivity: Initial state = ${_isOnline ? "ONLINE" : "OFFLINE"}');

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = _hasInternet(result);

      if (_isOnline != wasOnline) {
        debugPrint('Connectivity: Changed to ${_isOnline ? "ONLINE" : "OFFLINE"}');
        _onlineController.add(_isOnline);

        // When we come back online, sync pending data
        if (_isOnline) {
          syncPendingData();
        }
      }
    });
  }

  /// Check current connectivity (one-shot)
  Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = _hasInternet(result);
    return _isOnline;
  }

  /// Sync all unsynced chat data from SQLite → Firebase
  Future<void> syncPendingData() async {
    if (_isSyncing) return; // Prevent concurrent syncs
    if (_auth.userId.isEmpty) {
      debugPrint('Sync: Skipping — user not logged in');
      return;
    }

    _isSyncing = true;
    debugPrint('Sync: Starting sync of pending data...');

    try {
      // 1) Sync unsynced conversations
      final conversations = await _db.getUnsyncedConversations();
      debugPrint('Sync: ${conversations.length} conversations to sync');
      for (var conv in conversations) {
        try {
          await _firestore.saveConversation(conv);
          await _db.markConversationSynced(conv.id);
          debugPrint('Sync: Synced conversation ${conv.id}');
        } catch (e) {
          debugPrint('Sync: Failed to sync conversation ${conv.id}: $e');
        }
      }

      // 2) Sync unsynced messages
      final messages = await _db.getUnsyncedMessages();
      debugPrint('Sync: ${messages.length} messages to sync');
      for (var msg in messages) {
        try {
          await _firestore.saveChatMessage(msg);
          await _db.markMessageSynced(msg.id);
          debugPrint('Sync: Synced message ${msg.id}');
        } catch (e) {
          debugPrint('Sync: Failed to sync message ${msg.id}: $e');
        }
      }

      debugPrint('Sync: Completed successfully');
    } catch (e) {
      debugPrint('Sync: Error during sync: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Dispose — call when app closes
  void dispose() {
    _subscription?.cancel();
    _onlineController.close();
  }

  /// Check if any connectivity result indicates internet access
  bool _hasInternet(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
  }
}
