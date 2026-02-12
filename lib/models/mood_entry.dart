// mood_entry.dart - Model class for mood entries
// Represents a detected mood from chat data or manual input

class MoodEntry {
  // Unique identifier
  final String id;

  // Primary detected mood (happy, sad, anxious, etc.)
  final String mood;

  // Mood score: 1 (very negative) to 10 (very positive)
  final int score;

  // Optional note/context for the mood
  final String note;

  // Source: 'chat' (auto-detected) or 'manual' (user input)
  final String source;

  // When the mood was recorded
  final DateTime date;

  // Detected emotions breakdown (e.g., {'sad': 0.6, 'anxious': 0.3, 'hopeful': 0.1})
  final Map<String, double> emotionBreakdown;

  MoodEntry({
    required this.id,
    required this.mood,
    required this.score,
    this.note = '',
    this.source = 'manual',
    required this.date,
    this.emotionBreakdown = const {},
  });

  // Mood categories with score ranges
  static String moodFromScore(int score) {
    if (score >= 9) return 'excellent';
    if (score >= 7) return 'happy';
    if (score >= 5) return 'neutral';
    if (score >= 3) return 'sad';
    return 'distressed';
  }

  // Get emoji for mood
  static String getEmoji(String mood) {
    switch (mood.toLowerCase()) {
      case 'excellent':
        return '🤩';
      case 'happy':
        return '😊';
      case 'calm':
        return '😌';
      case 'neutral':
        return '😐';
      case 'sad':
        return '😢';
      case 'anxious':
        return '😰';
      case 'angry':
        return '😠';
      case 'stressed':
        return '😫';
      case 'distressed':
        return '😞';
      case 'grateful':
        return '🙏';
      case 'hopeful':
        return '🌟';
      default:
        return '😐';
    }
  }

  // Get color for mood (as int for Material Color)
  static int getColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'excellent':
        return 0xFF2E7D32; // Dark Green
      case 'happy':
        return 0xFF4CAF50; // Green
      case 'calm':
        return 0xFF2196F3; // Blue
      case 'neutral':
        return 0xFF9E9E9E; // Grey
      case 'sad':
        return 0xFF607D8B; // Blue Grey
      case 'anxious':
        return 0xFFFF9800; // Orange
      case 'angry':
        return 0xFFF44336; // Red
      case 'stressed':
        return 0xFF9C27B0; // Purple
      case 'distressed':
        return 0xFF795548; // Brown
      case 'grateful':
        return 0xFFE91E63; // Pink
      case 'hopeful':
        return 0xFFFFEB3B; // Yellow
      default:
        return 0xFF607D8B; // Blue Grey
    }
  }

  // Is this a negative mood?
  bool get isNegative => score <= 4;

  // Is this a positive mood?
  bool get isPositive => score >= 7;

  // Convert to Map for SQLite storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mood': mood,
      'score': score,
      'note': note,
      'source': source,
      'date': date.millisecondsSinceEpoch,
      'emotionBreakdown': emotionBreakdown.entries.map((e) => '${e.key}:${e.value}').join(','),
    };
  }

  // Create from SQLite Map
  factory MoodEntry.fromMap(Map<String, dynamic> map) {
    // Parse emotion breakdown string back to map
    Map<String, double> breakdown = {};
    final breakdownStr = map['emotionBreakdown'] as String? ?? '';
    if (breakdownStr.isNotEmpty) {
      for (var pair in breakdownStr.split(',')) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          breakdown[parts[0]] = double.tryParse(parts[1]) ?? 0.0;
        }
      }
    }

    return MoodEntry(
      id: map['id'] as String,
      mood: map['mood'] as String,
      score: map['score'] as int,
      note: map['note'] as String? ?? '',
      source: map['source'] as String? ?? 'manual',
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      emotionBreakdown: breakdown,
    );
  }

  // Convert to Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'mood': mood,
      'score': score,
      'note': note,
      'source': source,
      'date': date.toIso8601String(),
      'emotionBreakdown': emotionBreakdown,
    };
  }

  // Create from Firestore document
  factory MoodEntry.fromFirestore(Map<String, dynamic> map) {
    Map<String, double> breakdown = {};
    final rawBreakdown = map['emotionBreakdown'];
    if (rawBreakdown is Map) {
      for (var entry in rawBreakdown.entries) {
        breakdown[entry.key.toString()] = (entry.value as num).toDouble();
      }
    }

    return MoodEntry(
      id: map['id'] as String,
      mood: map['mood'] as String,
      score: (map['score'] as num).toInt(),
      note: map['note'] as String? ?? '',
      source: map['source'] as String? ?? 'manual',
      date: DateTime.parse(map['date'] as String),
      emotionBreakdown: breakdown,
    );
  }
}

/// Activity suggestion based on mood patterns
class ActivitySuggestion {
  final String title;
  final String description;
  final String icon; // Material icon name
  final String category; // 'breathing', 'movement', 'social', 'creative', 'mindfulness'

  const ActivitySuggestion({
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
  });
}
