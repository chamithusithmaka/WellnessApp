// chat_conversation_screen.dart - Active chat conversation with Serenity AI
// Provides real-time messaging with the AI emotional support bot
// Supports offline mode with hardcoded responses and SQLite storage

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/chat_message.dart';
import '../../services/firestore_service.dart';
import '../../services/gemini_service.dart';
import '../../services/mood_service.dart';
import '../../services/database_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/offline_response_service.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class ChatConversationScreen extends StatefulWidget {
  final ChatConversation conversation;
  final bool isNew;

  const ChatConversationScreen({
    super.key,
    required this.conversation,
    required this.isNew,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirestoreService _firestoreService = FirestoreService();
  final DatabaseService _databaseService = DatabaseService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final MoodService _moodService = MoodService();
  final FocusNode _focusNode = FocusNode();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isTyping = false;
  bool _conversationSaved = false;
  bool _isOnline = true;
  late String _conversationId;
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversation.id;
    _isOnline = _connectivityService.isOnline;

    // Listen for connectivity changes
    _connectivitySub = _connectivityService.onlineStream.listen((online) {
      if (mounted) {
        setState(() => _isOnline = online);
        if (online) {
          // Auto-sync when internet reconnects
          _connectivityService.syncPendingData();
        }
      }
    });

    if (!widget.isNew) {
      _loadMessages();
    } else {
      // For new conversations, send initial greeting
      _sendInitialGreeting();
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Load existing messages — tries local SQLite first, then Firestore
  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);

    try {
      debugPrint('Chat: Loading messages for conversation $_conversationId');

      // 1) Always load from local SQLite first (instant, works offline)
      final localMessages = await _databaseService
          .getConversationMessages(_conversationId);
      debugPrint('Chat: Loaded ${localMessages.length} messages from SQLite');

      if (localMessages.isNotEmpty) {
        setState(() {
          _messages = localMessages;
          _isLoading = false;
        });
        _scrollToBottom();
        return; // Local data is the source of truth
      }

      // 2) If no local data and online, try Firestore and cache locally
      if (_isOnline) {
        final cloudMessages = await _firestoreService
            .getConversationMessages(_conversationId);
        debugPrint('Chat: Loaded ${cloudMessages.length} messages from Firestore');

        // Cache to SQLite for future offline access
        for (var msg in cloudMessages) {
          await _databaseService.saveChatMessage(msg, isSynced: true);
        }

        setState(() {
          _messages = cloudMessages;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }

      _scrollToBottom();
    } catch (e) {
      debugPrint('Chat: ERROR loading messages: $e');
      setState(() => _isLoading = false);

      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load messages: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadMessages,
            ),
          ),
        );
      }
    }
  }

  // Show local greeting for new conversations — no API call needed
  void _sendInitialGreeting() {
    final greetings = [
      "Hello! I'm Serenity, your wellness companion 💙\n\nI'm here to listen and support you without any judgment. How are you feeling today?",
      "Hi there! I'm Serenity 🌿\n\nThis is a safe space for you to share whatever is on your heart and mind. How are you doing today?",
      "Welcome! I'm Serenity, and I'm so glad you're here 💙\n\nI'm here to listen, support, and walk alongside you. What's been on your mind lately?",
    ];

    // Pick a greeting based on the current time for variety
    final index = DateTime.now().millisecond % greetings.length;

    final aiMessage = ChatMessage(
      id: const Uuid().v4(),
      text: greetings[index],
      sender: 'ai',
      timestamp: DateTime.now(),
      conversationId: _conversationId,
    );

    setState(() {
      _messages.add(aiMessage);
    });
  }

  // Send user message and get AI response (online: Gemini, offline: hardcoded)
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isTyping) return;

    _messageController.clear();
    _focusNode.requestFocus();

    final now = DateTime.now();
    final userMessage = ChatMessage(
      id: const Uuid().v4(),
      text: text,
      sender: 'user',
      timestamp: now,
      conversationId: _conversationId,
    );

    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
    });

    _scrollToBottom();

    // Save user message to local SQLite immediately (offline-first)
    _saveLocally(text, userMessage, now);

    // Analyze mood from user message and save locally (non-blocking)
    _analyzeMoodFromMessage(text);

    // Check connectivity to decide response source
    final online = await _connectivityService.checkConnectivity();

    if (online) {
      // ===== ONLINE: Use Gemini API =====
      await _getOnlineResponse(text);
    } else {
      // ===== OFFLINE: Use hardcoded empathetic responses =====
      await _getOfflineResponse(text);
    }
  }

  // Get AI response from Gemini API (online mode)
  Future<void> _getOnlineResponse(String text) async {
    // Build conversation history for context
    final historyMessages = _messages.sublist(0, _messages.length - 1);

    List<Map<String, String>> history = [];
    for (var m in historyMessages) {
      final role = m.isUser ? 'user' : 'model';
      if (history.isNotEmpty && history.last['role'] == role) continue;
      history.add({'role': role, 'text': m.text});
    }
    while (history.isNotEmpty && history.first['role'] != 'user') {
      history.removeAt(0);
    }

    debugPrint('Chat: Sending message "$text" with ${history.length} history items');

    try {
      final response = await GeminiService.sendMessage(text, history);
      debugPrint('Chat: Got Gemini response, length: ${response.length}');

      final aiMessage = ChatMessage(
        id: const Uuid().v4(),
        text: response,
        sender: 'ai',
        timestamp: DateTime.now(),
        conversationId: _conversationId,
      );

      setState(() {
        _messages.add(aiMessage);
        _isTyping = false;
      });

      // Save AI message locally and to Firestore
      _databaseService.saveChatMessage(aiMessage, isSynced: false);
      _firestoreService.saveChatMessage(aiMessage).then((_) {
        _databaseService.markMessageSynced(aiMessage.id);
      }).timeout(
        const Duration(seconds: 5),
        onTimeout: () { debugPrint('Firestore: save AI message timed out'); },
      ).catchError((e) { debugPrint('Firestore: save AI message error: $e'); });

      // Update conversation last message
      final preview = response.length > 100 ? '${response.substring(0, 100)}...' : response;
      _databaseService.updateConversationLastMessage(_conversationId, preview, aiMessage.timestamp);
      _firestoreService.updateConversationLastMessage(_conversationId, preview, aiMessage.timestamp);

      _scrollToBottom();
    } catch (e) {
      debugPrint('Chat: Gemini failed ($e), falling back to offline response');
      // If Gemini fails (e.g. network drops mid-request), use offline response
      await _getOfflineResponse(text);
    }
  }

  // Get hardcoded empathetic response (offline mode)
  Future<void> _getOfflineResponse(String text) async {
    // Small delay to feel natural
    await Future.delayed(const Duration(milliseconds: 800));

    final response = OfflineResponseService.getResponse(text);

    final aiMessage = ChatMessage(
      id: const Uuid().v4(),
      text: response,
      sender: 'ai',
      timestamp: DateTime.now(),
      conversationId: _conversationId,
    );

    setState(() {
      _messages.add(aiMessage);
      _isTyping = false;
    });

    // Save offline AI response to SQLite (will sync to Firebase later)
    _databaseService.saveChatMessage(aiMessage, isSynced: false);
    final preview = response.length > 100 ? '${response.substring(0, 100)}...' : response;
    _databaseService.updateConversationLastMessage(_conversationId, preview, aiMessage.timestamp);

    _scrollToBottom();
  }

  // Save messages locally (SQLite) first — sync to Firebase when online
  Future<void> _saveLocally(String text, ChatMessage userMessage, DateTime now) async {
    try {
      if (!_conversationSaved) {
        _conversationSaved = true;

        final conversation = ChatConversation(
          id: _conversationId,
          title: 'New Chat',
          createdAt: now,
          lastMessageAt: now,
          lastMessage: text,
        );

        // Always save to SQLite first
        await _databaseService.saveConversation(conversation);

        // Save the initial AI greeting if it exists
        for (var msg in _messages) {
          if (msg.sender == 'ai') {
            await _databaseService.saveChatMessage(msg);
          }
        }

        // Generate title locally
        GeminiService.generateTitle(text).then((title) {
          _databaseService.updateConversationTitle(_conversationId, title);
        });

        // If online, also push to Firestore
        if (_isOnline) {
          _firestoreService.saveConversation(conversation).then((_) {
            _databaseService.markConversationSynced(conversation.id);
          }).timeout(
            const Duration(seconds: 5),
            onTimeout: () { debugPrint('Firestore: saveConversation timed out'); },
          ).catchError((e) { debugPrint('Firestore: saveConversation error: $e'); });

          for (var msg in _messages) {
            if (msg.sender == 'ai') {
              _firestoreService.saveChatMessage(msg).then((_) {
                _databaseService.markMessageSynced(msg.id);
              }).catchError((e) { debugPrint('Firestore: save greeting error: $e'); });
            }
          }

          GeminiService.generateTitle(text).then((title) {
            _firestoreService.updateConversationTitle(_conversationId, title);
          });
        }
      }

      // Save user message to SQLite
      await _databaseService.saveChatMessage(userMessage);
      _databaseService.updateConversationLastMessage(_conversationId, text, now);

      // If online, also push to Firestore
      if (_isOnline) {
        _firestoreService.saveChatMessage(userMessage).then((_) {
          _databaseService.markMessageSynced(userMessage.id);
        }).timeout(
          const Duration(seconds: 5),
          onTimeout: () { debugPrint('Firestore: saveChatMessage timed out'); },
        ).catchError((e) { debugPrint('Firestore: saveChatMessage error: $e'); });

        _firestoreService.updateConversationLastMessage(_conversationId, text, now);
      }
    } catch (e) {
      debugPrint('Local save error: $e');
    }
  }

  // Analyze mood from user message and save to local SQLite
  Future<void> _analyzeMoodFromMessage(String text) async {
    try {
      final result = MoodService.analyzeMessage(text);
      // Only save if we detected some emotion (not just neutral default)
      if (result.emotions.length > 1 || !result.emotions.containsKey('neutral')) {
        final entry = _moodService.analyzeDayMessages(
          [ChatMessage(
            id: const Uuid().v4(),
            text: text,
            sender: 'user',
            timestamp: DateTime.now(),
            conversationId: _conversationId,
          )],
          DateTime.now(),
        );
        await _moodService.saveMoodEntry(entry);
        debugPrint('Mood: Saved mood "${entry.mood}" (${entry.score}/10) from chat');
      }
    } catch (e) {
      debugPrint('Mood analysis error (non-blocking): $e');
    }
  }

  // Auto-scroll to bottom of chat
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Serenity',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_isTyping)
              Text(
                'typing...',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w400,
                ),
              )
            else if (!_isOnline)
              Text(
                'offline mode',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.error,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') _confirmClearChat();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20),
                    SizedBox(width: 8),
                    Text('Clear this chat'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Offline banner
          if (!_isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              color: colorScheme.errorContainer,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, size: 16, color: colorScheme.onErrorContainer),
                  const SizedBox(width: 6),
                  Text(
                    'You\'re offline — messages will sync when reconnected',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),

          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.psychology,
                              size: 64,
                              color: colorScheme.primary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Starting your session...',
                              style: TextStyle(color: colorScheme.outline),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: _messages.length + (_isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Typing indicator
                          if (index == _messages.length && _isTyping) {
                            return _TypingIndicator(colorScheme: colorScheme);
                          }

                          final message = _messages[index];
                          final showTime = _shouldShowTimestamp(index);

                          return Column(
                            children: [
                              if (showTime)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    _formatMessageTime(message.timestamp),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.outline,
                                    ),
                                  ),
                                ),
                              _MessageBubble(
                                message: message,
                                colorScheme: colorScheme,
                              ),
                            ],
                          );
                        },
                      ),
          ),

          // Input area
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              12,
              8,
              12,
              8 + MediaQuery.of(context).padding.bottom,
            ),
            child: Row(
              children: [
                // Message input
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Share what\'s on your mind...',
                        hintStyle: TextStyle(color: colorScheme.outline),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Send button
                Container(
                  decoration: BoxDecoration(
                    color: _isTyping
                        ? colorScheme.outline
                        : colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isTyping ? null : _sendMessage,
                    icon: Icon(
                      Icons.send_rounded,
                      color: colorScheme.onPrimary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Determine if we should show timestamp between messages
  bool _shouldShowTimestamp(int index) {
    if (index == 0) return true;
    final current = _messages[index].timestamp;
    final previous = _messages[index - 1].timestamp;
    return current.difference(previous).inMinutes > 15;
  }

  // Format message time
  String _formatMessageTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return 'Today ${DateFormat('h:mm a').format(time)}';
    } else if (diff.inDays == 1) {
      return 'Yesterday ${DateFormat('h:mm a').format(time)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(time);
    }
  }

  // Confirm clear this chat
  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text(
            'Delete this entire conversation? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Delete from both SQLite and Firestore
              _databaseService.deleteConversation(_conversationId);
              if (_isOnline) {
                _firestoreService.deleteConversation(_conversationId);
              }
              Navigator.pop(context); // Go back to chat list
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ==================== Message Bubble Widget ====================

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final ColorScheme colorScheme;

  const _MessageBubble({
    required this.message,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isUser ? 48 : 0,
          right: isUser ? 0 : 48,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // AI avatar
            if (!isUser) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.psychology,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Message bubble
            Flexible(
              child: GestureDetector(
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: message.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message copied'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft:
                          isUser ? const Radius.circular(18) : Radius.zero,
                      bottomRight:
                          isUser ? Radius.zero : const Radius.circular(18),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: isUser
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),

            // User avatar
            if (isUser) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundColor: colorScheme.secondaryContainer,
                child: Icon(
                  Icons.person,
                  size: 18,
                  color: colorScheme.secondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================== Typing Indicator Widget ====================

class _TypingIndicator extends StatefulWidget {
  final ColorScheme colorScheme;

  const _TypingIndicator({required this.colorScheme});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: widget.colorScheme.primaryContainer,
              child: Icon(
                Icons.psychology,
                size: 18,
                color: widget.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: widget.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (index) {
                      final delay = index * 0.2;
                      final value =
                          ((_controller.value + delay) % 1.0);
                      final opacity = (value < 0.5)
                          ? 0.3 + (value * 1.4)
                          : 1.0 - ((value - 0.5) * 1.4);

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        child: Opacity(
                          opacity: opacity.clamp(0.3, 1.0),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: widget.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
