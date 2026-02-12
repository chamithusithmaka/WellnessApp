// mood_service.dart - Analyzes chat messages to detect mood patterns
// Provides mood tracking, trend analysis, and activity suggestions

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/mood_entry.dart';
import '../models/chat_message.dart';
import 'database_service.dart';
import 'package:uuid/uuid.dart';

class MoodService {
  final DatabaseService _db = DatabaseService();

  // ==================== MOOD ANALYSIS FROM CHAT ====================

  /// Analyze a chat message and return a mood score (1-10) and detected emotions
  static MoodAnalysisResult analyzeMessage(String text) {
    final lowerText = text.toLowerCase();
    Map<String, double> emotions = {};
    double totalWeight = 0;

    // Positive emotion keywords and weights
    final positiveKeywords = {
      'happy': ['happy', 'joy', 'joyful', 'delighted', 'cheerful', 'elated', 'thrilled'],
      'calm': ['calm', 'peaceful', 'relaxed', 'serene', 'tranquil', 'at ease', 'comfortable'],
      'grateful': ['grateful', 'thankful', 'blessed', 'appreciate', 'appreciation', 'fortunate'],
      'hopeful': ['hopeful', 'optimistic', 'looking forward', 'excited', 'motivated', 'inspired'],
      'excellent': ['amazing', 'wonderful', 'fantastic', 'incredible', 'awesome', 'great', 'perfect'],
    };

    // Negative emotion keywords and weights
    final negativeKeywords = {
      'sad': ['sad', 'unhappy', 'depressed', 'down', 'miserable', 'heartbroken', 'grief', 'lonely', 'alone', 'crying', 'tears'],
      'anxious': ['anxious', 'worried', 'nervous', 'panic', 'fear', 'scared', 'terrified', 'uneasy', 'overthinking', 'restless'],
      'angry': ['angry', 'furious', 'rage', 'frustrated', 'irritated', 'annoyed', 'mad', 'upset'],
      'stressed': ['stressed', 'overwhelmed', 'pressure', 'burnout', 'exhausted', 'drained', 'tired', 'burnt out', 'overloaded'],
      'distressed': ['helpless', 'hopeless', 'worthless', 'broken', 'suffering', 'pain', 'hurt', 'struggling', 'desperate', 'suicidal', 'self-harm'],
    };

    // Neutral/mild keywords
    final neutralKeywords = {
      'neutral': ['okay', 'fine', 'alright', 'so-so', 'meh', 'not bad', 'decent', 'average'],
    };

    // Scan for positive emotions
    for (var entry in positiveKeywords.entries) {
      for (var keyword in entry.value) {
        if (lowerText.contains(keyword)) {
          emotions[entry.key] = (emotions[entry.key] ?? 0) + 1.0;
          totalWeight += 1.0;
        }
      }
    }

    // Scan for negative emotions
    for (var entry in negativeKeywords.entries) {
      for (var keyword in entry.value) {
        if (lowerText.contains(keyword)) {
          emotions[entry.key] = (emotions[entry.key] ?? 0) + 1.0;
          totalWeight += 1.0;
        }
      }
    }

    // Scan for neutral emotions
    for (var entry in neutralKeywords.entries) {
      for (var keyword in entry.value) {
        if (lowerText.contains(keyword)) {
          emotions[entry.key] = (emotions[entry.key] ?? 0) + 1.0;
          totalWeight += 1.0;
        }
      }
    }

    // Negation detection — "not happy" should flip sentiment
    final negationPatterns = ['not ', "don't ", "can't ", "isn't ", "aren't ", "won't ", "doesn't ", 'never '];
    for (var neg in negationPatterns) {
      for (var posKey in positiveKeywords.keys) {
        for (var keyword in positiveKeywords[posKey]!) {
          if (lowerText.contains('$neg$keyword')) {
            // Remove the positive match, add negative
            emotions[posKey] = (emotions[posKey] ?? 0) - 1.0;
            emotions['sad'] = (emotions['sad'] ?? 0) + 0.5;
          }
        }
      }
    }

    // Clean up: remove zero/negative emotion entries
    emotions.removeWhere((key, value) => value <= 0);

    // Calculate mood score
    if (totalWeight == 0) {
      // No emotional keywords found — default to neutral
      return MoodAnalysisResult(score: 5, mood: 'neutral', emotions: {'neutral': 1.0});
    }

    // Normalize emotion breakdown to percentages
    Map<String, double> normalizedEmotions = {};
    for (var entry in emotions.entries) {
      normalizedEmotions[entry.key] = entry.value / totalWeight;
    }

    // Calculate weighted score
    double weightedScore = 0;
    final scoreMap = {
      'excellent': 10.0,
      'happy': 8.0,
      'grateful': 8.5,
      'hopeful': 7.5,
      'calm': 7.0,
      'neutral': 5.0,
      'stressed': 3.5,
      'angry': 3.0,
      'anxious': 3.0,
      'sad': 2.5,
      'distressed': 1.5,
    };

    for (var entry in normalizedEmotions.entries) {
      weightedScore += (scoreMap[entry.key] ?? 5.0) * entry.value;
    }

    int finalScore = weightedScore.round().clamp(1, 10);
    String primaryMood = MoodEntry.moodFromScore(finalScore);

    // If there's a clear dominant emotion, use it
    if (normalizedEmotions.isNotEmpty) {
      final dominant = normalizedEmotions.entries.reduce((a, b) => a.value > b.value ? a : b);
      if (dominant.value > 0.5) {
        primaryMood = dominant.key;
      }
    }

    return MoodAnalysisResult(
      score: finalScore,
      mood: primaryMood,
      emotions: normalizedEmotions,
    );
  }

  /// Analyze multiple chat messages from a day and create a mood entry
  MoodEntry analyzeDayMessages(List<ChatMessage> messages, DateTime date) {
    if (messages.isEmpty) {
      return MoodEntry(
        id: const Uuid().v4(),
        mood: 'neutral',
        score: 5,
        source: 'chat',
        date: date,
      );
    }

    // Only analyze user messages (not AI responses)
    final userMessages = messages.where((m) => m.isUser).toList();
    if (userMessages.isEmpty) {
      return MoodEntry(
        id: const Uuid().v4(),
        mood: 'neutral',
        score: 5,
        source: 'chat',
        date: date,
      );
    }

    // Combine all user messages and analyze
    final combinedText = userMessages.map((m) => m.text).join(' ');
    final result = analyzeMessage(combinedText);

    return MoodEntry(
      id: const Uuid().v4(),
      mood: result.mood,
      score: result.score,
      note: 'Detected from ${userMessages.length} chat message${userMessages.length > 1 ? 's' : ''}',
      source: 'chat',
      date: date,
      emotionBreakdown: result.emotions,
    );
  }

  // ==================== MOOD PERSISTENCE (SQLite) ====================

  /// Save a mood entry to local DB
  Future<void> saveMoodEntry(MoodEntry entry) async {
    final db = await _db.database;
    await db.insert(
      'mood_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('MoodService: Saved mood entry ${entry.mood} (${entry.score})');
  }

  /// Get all mood entries (newest first)
  Future<List<MoodEntry>> getAllMoodEntries() async {
    final db = await _db.database;
    final maps = await db.query('mood_entries', orderBy: 'date DESC');
    return maps.map((m) => MoodEntry.fromMap(m)).toList();
  }

  /// Get mood entries for the last N days
  Future<List<MoodEntry>> getRecentMoodEntries(int days) async {
    final db = await _db.database;
    final cutoff = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final maps = await db.query(
      'mood_entries',
      where: 'date >= ?',
      whereArgs: [cutoff],
      orderBy: 'date ASC',
    );
    return maps.map((m) => MoodEntry.fromMap(m)).toList();
  }

  /// Get today's mood entry
  Future<MoodEntry?> getTodayMood() async {
    final db = await _db.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;

    final maps = await db.query(
      'mood_entries',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'date DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return MoodEntry.fromMap(maps.first);
  }

  /// Get average mood score for the last N days
  Future<double> getAverageMoodScore(int days) async {
    final entries = await getRecentMoodEntries(days);
    if (entries.isEmpty) return 5.0;
    final total = entries.fold<int>(0, (sum, e) => sum + e.score);
    return total / entries.length;
  }

  /// Get mood distribution for a time period (for pie chart)
  Future<Map<String, int>> getMoodDistribution(int days) async {
    final entries = await getRecentMoodEntries(days);
    Map<String, int> distribution = {};
    for (var entry in entries) {
      distribution[entry.mood] = (distribution[entry.mood] ?? 0) + 1;
    }
    return distribution;
  }

  /// Get daily mood scores for line chart
  Future<List<DailyMoodData>> getDailyMoodScores(int days) async {
    final entries = await getRecentMoodEntries(days);
    Map<String, List<MoodEntry>> grouped = {};

    for (var entry in entries) {
      final dayKey = '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(dayKey, () => []);
      grouped[dayKey]!.add(entry);
    }

    List<DailyMoodData> dailyData = [];
    for (var entry in grouped.entries) {
      final avgScore = entry.value.fold<int>(0, (s, e) => s + e.score) / entry.value.length;
      final date = DateTime.parse(entry.key);
      dailyData.add(DailyMoodData(date: date, score: avgScore));
    }

    dailyData.sort((a, b) => a.date.compareTo(b.date));
    return dailyData;
  }

  /// Detect current mood trend (improving, declining, stable)
  Future<MoodTrend> getMoodTrend() async {
    final recentEntries = await getRecentMoodEntries(14);
    if (recentEntries.length < 3) return MoodTrend.insufficient;

    // Compare first half vs second half average
    final midpoint = recentEntries.length ~/ 2;
    final firstHalf = recentEntries.sublist(0, midpoint);
    final secondHalf = recentEntries.sublist(midpoint);

    final firstAvg = firstHalf.fold<int>(0, (s, e) => s + e.score) / firstHalf.length;
    final secondAvg = secondHalf.fold<int>(0, (s, e) => s + e.score) / secondHalf.length;

    final diff = secondAvg - firstAvg;
    if (diff > 1.0) return MoodTrend.improving;
    if (diff < -1.0) return MoodTrend.declining;
    return MoodTrend.stable;
  }

  // ==================== ACTIVITY SUGGESTIONS ====================

  /// Get activity suggestions based on current mood pattern
  List<ActivitySuggestion> getActivitySuggestions(String mood, int score) {
    List<ActivitySuggestion> suggestions = [];

    // Universal suggestions
    suggestions.add(const ActivitySuggestion(
      title: 'Mindful Breathing',
      description: 'Take 5 deep breaths. Inhale for 4s, hold 4s, exhale 6s.',
      icon: 'air',
      category: 'breathing',
    ));

    if (score <= 3) {
      // Very low mood
      suggestions.addAll([
        const ActivitySuggestion(
          title: 'Grounding Exercise',
          description: 'Name 5 things you see, 4 you touch, 3 you hear, 2 you smell, 1 you taste.',
          icon: 'self_improvement',
          category: 'mindfulness',
        ),
        const ActivitySuggestion(
          title: 'Reach Out',
          description: 'Text or call someone you trust. Connection helps during tough times.',
          icon: 'people',
          category: 'social',
        ),
        const ActivitySuggestion(
          title: 'Gentle Walk',
          description: 'A short 10-minute walk outside can significantly boost your mood.',
          icon: 'directions_walk',
          category: 'movement',
        ),
        const ActivitySuggestion(
          title: 'Listen to Calming Music',
          description: 'Put on soothing sounds or your favorite calming playlist.',
          icon: 'music_note',
          category: 'creative',
        ),
      ]);
    } else if (score <= 5) {
      // Low/neutral mood
      suggestions.addAll([
        const ActivitySuggestion(
          title: 'Gratitude List',
          description: 'Write down 3 things you\'re grateful for, no matter how small.',
          icon: 'favorite',
          category: 'mindfulness',
        ),
        const ActivitySuggestion(
          title: 'Light Stretching',
          description: '5 minutes of gentle stretches to release physical tension.',
          icon: 'fitness_center',
          category: 'movement',
        ),
        const ActivitySuggestion(
          title: 'Creative Expression',
          description: 'Draw, doodle, or write freely for 10 minutes without judgment.',
          icon: 'brush',
          category: 'creative',
        ),
        const ActivitySuggestion(
          title: 'Nature Break',
          description: 'Step outside and observe nature for a few minutes. Fresh air helps.',
          icon: 'park',
          category: 'movement',
        ),
      ]);
    } else if (score <= 7) {
      // Neutral/positive mood
      suggestions.addAll([
        const ActivitySuggestion(
          title: 'Journaling',
          description: 'Write about what\'s going well today. Reinforce positive patterns.',
          icon: 'edit_note',
          category: 'mindfulness',
        ),
        const ActivitySuggestion(
          title: 'Random Act of Kindness',
          description: 'Do something nice for someone. Kindness boosts your own happiness too.',
          icon: 'volunteer_activism',
          category: 'social',
        ),
      ]);
    } else {
      // High mood — maintain it
      suggestions.addAll([
        const ActivitySuggestion(
          title: 'Celebrate This Feeling',
          description: 'Notice what\'s contributing to your good mood. Savor it!',
          icon: 'celebration',
          category: 'mindfulness',
        ),
        const ActivitySuggestion(
          title: 'Share Your Joy',
          description: 'Tell someone about something good that happened to you.',
          icon: 'share',
          category: 'social',
        ),
      ]);
    }

    // Mood-specific extras
    if (mood == 'anxious' || mood == 'stressed') {
      suggestions.add(const ActivitySuggestion(
        title: 'Progressive Muscle Relaxation',
        description: 'Tense and release each muscle group for 5 seconds. Start from your toes.',
        icon: 'accessibility_new',
        category: 'breathing',
      ));
    }

    if (mood == 'angry') {
      suggestions.add(const ActivitySuggestion(
        title: 'Physical Release',
        description: 'Try jumping jacks, push-ups, or running in place for 2 minutes.',
        icon: 'sports_martial_arts',
        category: 'movement',
      ));
    }

    if (mood == 'sad' || mood == 'distressed') {
      suggestions.add(const ActivitySuggestion(
        title: 'Self-Compassion Pause',
        description: 'Place your hand on your heart. Say: "This is hard, but I\'m not alone."',
        icon: 'healing',
        category: 'mindfulness',
      ));
    }

    return suggestions;
  }

}

// ==================== HELPER CLASSES ====================

/// Result from mood analysis
class MoodAnalysisResult {
  final int score;
  final String mood;
  final Map<String, double> emotions;

  MoodAnalysisResult({
    required this.score,
    required this.mood,
    required this.emotions,
  });
}

/// Daily mood data point for charts
class DailyMoodData {
  final DateTime date;
  final double score;

  DailyMoodData({required this.date, required this.score});
}

/// Mood trend direction
enum MoodTrend {
  improving,
  declining,
  stable,
  insufficient, // Not enough data
}


