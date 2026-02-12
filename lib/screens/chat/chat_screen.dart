// chat_screen.dart - Main Chat Screen with conversation list & active chat
// Users can talk with Serenity AI for emotional support

import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../services/firestore_service.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'chat_conversation_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with Serenity'),
        actions: [
          // Clear all history button
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear all chats',
            onPressed: _confirmClearAll,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.secondaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.psychology,
                    size: 32,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Serenity AI',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your compassionate wellness companion 💙',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.8),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Conversations list label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Your Conversations',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const Spacer(),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Conversations list
          Expanded(
            child: StreamBuilder<List<ChatConversation>>(
              stream: _firestoreService.streamConversations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final conversations = snapshot.data ?? [];

                if (conversations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: colorScheme.outline.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No conversations yet',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: colorScheme.outline),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a new chat with Serenity!',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: colorScheme.outline),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final convo = conversations[index];
                    return _ConversationTile(
                      conversation: convo,
                      onTap: () => _openConversation(convo),
                      onDelete: () => _confirmDeleteConversation(convo),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // New chat FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewConversation,
        icon: const Icon(Icons.add_comment),
        label: const Text('New Chat'),
      ),
    );
  }

  // Start a new conversation
  void _startNewConversation() {
    final conversationId = const Uuid().v4();
    final now = DateTime.now();

    final conversation = ChatConversation(
      id: conversationId,
      title: 'New Chat',
      createdAt: now,
      lastMessageAt: now,
      lastMessage: '',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatConversationScreen(
          conversation: conversation,
          isNew: true,
        ),
      ),
    );
  }

  // Open existing conversation
  void _openConversation(ChatConversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatConversationScreen(
          conversation: conversation,
          isNew: false,
        ),
      ),
    );
  }

  // Confirm delete single conversation
  void _confirmDeleteConversation(ChatConversation convo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: Text(
            'Are you sure you want to delete "${convo.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _firestoreService.deleteConversation(convo.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Confirm clear all conversations
  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Chats'),
        content: const Text(
            'Are you sure you want to delete all conversations? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _firestoreService.clearChatHistory();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }
}

// Single conversation tile widget
class _ConversationTile extends StatelessWidget {
  final ChatConversation conversation;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeStr = _formatTime(conversation.lastMessageAt);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(
            Icons.chat_bubble,
            color: colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          conversation.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: conversation.lastMessage.isNotEmpty
            ? Text(
                conversation.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              )
            : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.outline,
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: onDelete,
              child: Icon(
                Icons.delete_outline,
                size: 18,
                color: colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays == 0) {
      return DateFormat('h:mm a').format(dateTime);
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat('EEEE').format(dateTime);
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }
}
