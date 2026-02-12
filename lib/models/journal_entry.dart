// journal_entry.dart - Model class for journal entries
// This represents a single journal entry with text, emotion, and date

class JournalEntry {
  // Unique identifier for the entry
  final String id;

  // The actual journal text written by user
  final String text;

  // Emotion associated with this entry (happy, sad, anxious, etc.)
  final String emotion;

  // When the entry was created
  final DateTime date;

  // Whether this entry has been synced to Firestore
  bool isSynced;

  // Constructor
  JournalEntry({
    required this.id,
    required this.text,
    required this.emotion,
    required this.date,
    this.isSynced = false,
  });

  // Convert JournalEntry to Map for SQLite storage
  // SQLite doesn't support DateTime, so we convert to milliseconds
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'emotion': emotion,
      'date': date.millisecondsSinceEpoch, // Store as integer
      'isSynced': isSynced ? 1 : 0, // SQLite uses 1/0 for boolean
    };
  }

  // Create JournalEntry from SQLite Map
  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    return JournalEntry(
      id: map['id'] as String,
      text: map['text'] as String,
      emotion: map['emotion'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      isSynced: (map['isSynced'] as int) == 1,
    );
  }

  // Convert JournalEntry to Map for Firestore
  // Firestore can handle DateTime directly
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'text': text,
      'emotion': emotion,
      'date': date.toIso8601String(), // Store as ISO string
    };
  }

  // Create JournalEntry from Firestore document
  factory JournalEntry.fromFirestore(Map<String, dynamic> map) {
    return JournalEntry(
      id: map['id'] as String,
      text: map['text'] as String,
      emotion: map['emotion'] as String,
      date: DateTime.parse(map['date'] as String),
      isSynced: true, // If it's from Firestore, it's synced
    );
  }

  // Create a copy with updated fields
  // Useful for editing entries
  JournalEntry copyWith({
    String? id,
    String? text,
    String? emotion,
    DateTime? date,
    bool? isSynced,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      text: text ?? this.text,
      emotion: emotion ?? this.emotion,
      date: date ?? this.date,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  // Get emoji for emotion (static method for use in UI)
  static String getEmoji(String emotion) {
    return Emotions.getEmoji(emotion);
  }

  // Get color for emotion (static method for use in UI)
  static int getColor(String emotion) {
    return Emotions.getColor(emotion);
  }
}

// List of available emotions for the app
// Used in journal entry form
class Emotions {
  static const List<String> list = [
    'happy',
    'calm',
    'sad',
    'anxious',
    'angry',
    'stressed',
    'grateful',
    'hopeful',
  ];

  // Get emoji for each emotion
  static String getEmoji(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return '😊';
      case 'calm':
        return '😌';
      case 'sad':
        return '😢';
      case 'anxious':
        return '😰';
      case 'angry':
        return '😠';
      case 'stressed':
        return '😫';
      case 'grateful':
        return '🙏';
      case 'hopeful':
        return '🌟';
      default:
        return '😐';
    }
  }

  // Get color for each emotion (for charts)
  static int getColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return 0xFF4CAF50; // Green
      case 'calm':
        return 0xFF2196F3; // Blue
      case 'sad':
        return 0xFF9E9E9E; // Grey
      case 'anxious':
        return 0xFFFF9800; // Orange
      case 'angry':
        return 0xFFF44336; // Red
      case 'stressed':
        return 0xFF9C27B0; // Purple
      case 'grateful':
        return 0xFFE91E63; // Pink
      case 'hopeful':
        return 0xFFFFEB3B; // Yellow
      default:
        return 0xFF607D8B; // Blue Grey
    }
  }
}