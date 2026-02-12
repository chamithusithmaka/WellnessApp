// chat_conversation_screen.dart - Active chat conversation with Serenity AI
// Provides real-time messaging with the AI emotional support bot

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/chat_message.dart';
import '../../services/firestore_service.dart';
import '../../services/gemini_service.dart';
import '../../services/mood_service.dart';
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
  final MoodService _moodService = MoodService();
  final FocusNode _focusNode = FocusNode();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isTyping = false;
  bool _conversationSaved = false;
  late String _conversationId;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversation.id;

    if (!widget.isNew) {
      _loadMessages();
    } else {
      // For new conversations, send initial greeting
      _sendInitialGreeting();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Load existing messages from Firestore
  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);

    try {
      final messages = await _firestoreService
          .getConversationMessages(_conversationId);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
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

  // Send user message and get AI response
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

    // Save to Firestore in background — don't block the AI response
    _saveToFirestore(text, userMessage, now);

    // Analyze mood from user message and save locally (non-blocking)
    _analyzeMoodFromMessage(text);

    // Build conversation history for context
    // EXCLUDE the current user message — sendMessage() adds it separately
    final historyMessages = _messages.sublist(0, _messages.length - 1);

    // Build history in Gemini format (user/model)
    List<Map<String, String>> history = [];
    for (var m in historyMessages) {
      final role = m.isUser ? 'user' : 'model';
      // Skip if this would create consecutive same-role messages
      if (history.isNotEmpty && history.last['role'] == role) continue;
      history.add({'role': role, 'text': m.text});
    }
    // Gemini requires history to start with 'user', not 'model'
    while (history.isNotEmpty && history.first['role'] != 'user') {
      history.removeAt(0);
    }

    debugPrint('Chat: Sending message "$text" with ${history.length} history items');
    debugPrint('Chat: History roles: ${history.map((h) => h['role']).toList()}');

    try {
      // Get AI response via Gemini
      final response = await GeminiService.sendMessage(text, history);
      debugPrint('Chat: Got response, length: ${response.length}');

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

      // Save AI response to Firestore (non-blocking)
      _firestoreService.saveChatMessage(aiMessage).timeout(
        const Duration(seconds: 5),
        onTimeout: () => debugPrint('Firestore: save AI message timed out'),
      ).catchError((e) => debugPrint('Firestore: save AI message error: $e'));

      // Update conversation's last message with AI reply (non-blocking)
      _firestoreService.updateConversationLastMessage(
        _conversationId,
        response.length > 100 ? '${response.substring(0, 100)}...' : response,
        aiMessage.timestamp,
      );

      _scrollToBottom();
    } catch (e) {
      debugPrint('Chat: ERROR getting AI response: $e');
      setState(() => _isTyping = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Save messages to Firestore in background — never blocks the AI call
  Future<void> _saveToFirestore(String text, ChatMessage userMessage, DateTime now) async {
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
        await _firestoreService.saveConversation(conversation).timeout(
          const Duration(seconds: 5),
          onTimeout: () => debugPrint('Firestore: saveConversation timed out'),
        );

        // Save the initial AI greeting if it exists
        for (var msg in _messages) {
          if (msg.sender == 'ai') {
            await _firestoreService.saveChatMessage(msg).timeout(
              const Duration(seconds: 5),
              onTimeout: () => debugPrint('Firestore: saveChatMessage timed out'),
            );
          }
        }

        // Generate title in background
        GeminiService.generateTitle(text).then((title) {
          _firestoreService.updateConversationTitle(_conversationId, title);
        });
      }

      await _firestoreService.saveChatMessage(userMessage).timeout(
        const Duration(seconds: 5),
        onTimeout: () => debugPrint('Firestore: saveChatMessage timed out'),
      );

      _firestoreService.updateConversationLastMessage(_conversationId, text, now);
    } catch (e) {
      debugPrint('Firestore save error (non-blocking): $e');
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
              _firestoreService.deleteConversation(_conversationId);
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
