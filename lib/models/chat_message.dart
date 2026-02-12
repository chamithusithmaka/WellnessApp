// chat_message.dart - Model class for chat messages
// Represents a single message in the chat with the AI

class ChatMessage {
  // Unique identifier
  final String id;

  // The message text
  final String text;

  // Who sent the message: 'user' or 'ai'
  final String sender;

  // When the message was sent
  final DateTime timestamp;

  // Conversation ID this message belongs to
  final String conversationId;

  // Constructor
  ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    required this.conversationId,
  });

  // Check if this message is from the user
  bool get isUser => sender == 'user';

  // Convert to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'text': text,
      'sender': sender,
      'timestamp': timestamp.toIso8601String(),
      'conversationId': conversationId,
    };
  }

  // Create from Firestore document
  factory ChatMessage.fromFirestore(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      text: map['text'] as String,
      sender: map['sender'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      conversationId: map['conversationId'] as String? ?? '',
    );
  }
}

// Represents a chat conversation/session
class ChatConversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final String lastMessage;

  ChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastMessageAt,
    required this.lastMessage,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'lastMessageAt': lastMessageAt.toIso8601String(),
      'lastMessage': lastMessage,
    };
  }

  factory ChatConversation.fromFirestore(Map<String, dynamic> map) {
    return ChatConversation(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Chat',
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastMessageAt: DateTime.parse(map['lastMessageAt'] as String),
      lastMessage: map['lastMessage'] as String? ?? '',
    );
  }
}
