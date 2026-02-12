// mood_screen.dart - Mood Detection and Analytics
// Tracks emotional trends, displays graphs/statistics, suggests activities

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/mood_entry.dart';
import '../../models/chat_message.dart';
import '../../services/mood_service.dart';
import '../../services/firestore_service.dart';

class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> with SingleTickerProviderStateMixin {
  final MoodService _moodService = MoodService();
  final FirestoreService _firestoreService = FirestoreService();

  late TabController _tabController;

  // Data
  List<MoodEntry> _recentEntries = [];
  List<DailyMoodData> _dailyScores = [];
  Map<String, int> _moodDistribution = {};
  MoodTrend _trend = MoodTrend.insufficient;
  double _averageScore = 5.0;
  MoodEntry? _todayMood;
  List<ActivitySuggestion> _suggestions = [];
  bool _isLoading = true;
  int _selectedDays = 7; // Default to last 7 days

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Try to analyze today's chat data if no mood entry exists yet
      await _analyzeTodayChatsIfNeeded();

      // Load all mood data
      final entries = await _moodService.getRecentMoodEntries(_selectedDays);
      final dailyScores = await _moodService.getDailyMoodScores(_selectedDays);
      final distribution = await _moodService.getMoodDistribution(_selectedDays);
      final trend = await _moodService.getMoodTrend();
      final avg = await _moodService.getAverageMoodScore(_selectedDays);
      final today = await _moodService.getTodayMood();

      // Get activity suggestions based on latest mood
      List<ActivitySuggestion> suggestions = [];
      if (today != null) {
        suggestions = _moodService.getActivitySuggestions(today.mood, today.score);
      } else if (entries.isNotEmpty) {
        final latest = entries.last;
        suggestions = _moodService.getActivitySuggestions(latest.mood, latest.score);
      } else {
        suggestions = _moodService.getActivitySuggestions('neutral', 5);
      }

      setState(() {
        _recentEntries = entries;
        _dailyScores = dailyScores;
        _moodDistribution = distribution;
        _trend = trend;
        _averageScore = avg;
        _todayMood = today;
        _suggestions = suggestions;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('MoodScreen: Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Analyze today's chats and generate a mood entry if one doesn't exist yet
  Future<void> _analyzeTodayChatsIfNeeded() async {
    try {
      final existing = await _moodService.getTodayMood();
      if (existing != null && existing.source == 'chat') return;

      // Try to get today's chat messages from Firestore
      // If Firestore fails (API disabled/timeout), mood analysis still works
      // because the chat screen saves mood entries locally after each message
      try {
        final conversations = await _firestoreService.getConversations()
            .timeout(const Duration(seconds: 5));
        if (conversations.isNotEmpty) {
          final now = DateTime.now();
          final startOfDay = DateTime(now.year, now.month, now.day);

          List<ChatMessage> todayMessages = [];
          for (var conv in conversations) {
            if (conv.lastMessageAt.isAfter(startOfDay)) {
              final messages = await _firestoreService
                  .getConversationMessages(conv.id)
                  .timeout(const Duration(seconds: 5));
              todayMessages.addAll(
                messages.where((m) => m.timestamp.isAfter(startOfDay) && m.isUser),
              );
            }
          }

          if (todayMessages.isNotEmpty) {
            final moodEntry = _moodService.analyzeDayMessages(todayMessages, DateTime.now());
            await _moodService.saveMoodEntry(moodEntry);

            // Also save to Firestore (non-blocking)
            _firestoreService.saveMoodEntry(moodEntry).catchError(
              (e) => debugPrint('Firestore: save mood error: $e'),
            );
          }
        }
      } catch (e) {
        debugPrint('MoodScreen: Firestore chat fetch failed (using local data): $e');
      }
    } catch (e) {
      debugPrint('MoodScreen: Error analyzing chats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood Analytics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.show_chart), text: 'Trends'),
            Tab(icon: Icon(Icons.pie_chart), text: 'Overview'),
            Tab(icon: Icon(Icons.tips_and_updates), text: 'Activities'),
          ],
        ),
        actions: [
          // Time range selector
          PopupMenuButton<int>(
            icon: const Icon(Icons.date_range),
            tooltip: 'Time range',
            onSelected: (days) {
              setState(() => _selectedDays = days);
              _loadData();
            },
            itemBuilder: (context) => [
              _buildRangeItem(7, 'Last 7 days'),
              _buildRangeItem(14, 'Last 14 days'),
              _buildRangeItem(30, 'Last 30 days'),
              _buildRangeItem(90, 'Last 3 months'),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTrendsTab(colorScheme),
                _buildOverviewTab(colorScheme),
                _buildActivitiesTab(colorScheme),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showManualMoodDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Log Mood'),
      ),
    );
  }

  PopupMenuItem<int> _buildRangeItem(int days, String label) {
    return PopupMenuItem(
      value: days,
      child: Row(
        children: [
          if (_selectedDays == days)
            Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  // ==================== TRENDS TAB ====================

  Widget _buildTrendsTab(ColorScheme colorScheme) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTodayMoodCard(colorScheme),
            const SizedBox(height: 16),
            _buildTrendCard(colorScheme),
            const SizedBox(height: 16),
            Text(
              'Mood Over Time',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            _buildMoodLineChart(colorScheme),
            const SizedBox(height: 16),
            Text(
              'Recent Entries',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            _buildRecentEntriesList(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayMoodCard(ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _todayMood != null
                    ? Color(MoodEntry.getColor(_todayMood!.mood)).withValues(alpha: 0.15)
                    : colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _todayMood != null ? MoodEntry.getEmoji(_todayMood!.mood) : '🤔',
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _todayMood != null ? "Today's Mood" : 'No Mood Logged',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (_todayMood != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${_todayMood!.mood[0].toUpperCase()}${_todayMood!.mood.substring(1)} • Score: ${_todayMood!.score}/10',
                      style: TextStyle(
                        color: Color(MoodEntry.getColor(_todayMood!.mood)),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_todayMood!.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _todayMood!.note,
                        style: TextStyle(color: colorScheme.outline, fontSize: 13),
                      ),
                    ],
                  ] else ...[
                    const SizedBox(height: 4),
                    Text(
                      'Chat with Serenity or tap "Log Mood" to track your emotions.',
                      style: TextStyle(color: colorScheme.outline, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendCard(ColorScheme colorScheme) {
    IconData trendIcon;
    Color trendColor;
    String trendText;

    switch (_trend) {
      case MoodTrend.improving:
        trendIcon = Icons.trending_up;
        trendColor = Colors.green;
        trendText = 'Your mood is improving! Keep it up! 🎉';
        break;
      case MoodTrend.declining:
        trendIcon = Icons.trending_down;
        trendColor = Colors.orange;
        trendText = 'Your mood has been dipping. Check the Activities tab for suggestions. 💙';
        break;
      case MoodTrend.stable:
        trendIcon = Icons.trending_flat;
        trendColor = Colors.blue;
        trendText = 'Your mood has been steady. Consistency is good! 😌';
        break;
      case MoodTrend.insufficient:
        trendIcon = Icons.info_outline;
        trendColor = Colors.grey;
        trendText = 'Keep logging your mood to see trends (need at least 3 entries).';
        break;
    }

    return Card(
      elevation: 0,
      color: trendColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(trendIcon, color: trendColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Trend', style: TextStyle(fontWeight: FontWeight.bold, color: trendColor)),
                      const Spacer(),
                      Text(
                        'Avg: ${_averageScore.toStringAsFixed(1)}/10',
                        style: TextStyle(color: trendColor, fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(trendText, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodLineChart(ColorScheme colorScheme) {
    if (_dailyScores.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.show_chart, size: 48, color: colorScheme.outline.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Text('No mood data yet', style: TextStyle(color: colorScheme.outline)),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 24, 16, 8),
        child: SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 10,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 2,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: colorScheme.outline.withValues(alpha: 0.1),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 2,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(fontSize: 11, color: colorScheme.outline),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: _dailyScores.length > 14 ? 7 : (_dailyScores.length > 7 ? 2 : 1),
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= _dailyScores.length) return const Text('');
                      final date = _dailyScores[index].date;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DateFormat('M/d').format(date),
                          style: TextStyle(fontSize: 10, color: colorScheme.outline),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: _dailyScores.asMap().entries.map((entry) {
                    return FlSpot(entry.key.toDouble(), entry.value.score);
                  }).toList(),
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: colorScheme.primary,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  belowBarData: BarAreaData(
                    show: true,
                    color: colorScheme.primary.withValues(alpha: 0.1),
                  ),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, __, ___) {
                      Color dotColor;
                      if (spot.y >= 7) {
                        dotColor = Colors.green;
                      } else if (spot.y >= 4) {
                        dotColor = Colors.blue;
                      } else {
                        dotColor = Colors.orange;
                      }
                      return FlDotCirclePainter(
                        radius: 4,
                        color: dotColor,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) {
                    return spots.map((spot) {
                      final index = spot.x.toInt();
                      if (index < 0 || index >= _dailyScores.length) return null;
                      final data = _dailyScores[index];
                      final mood = MoodEntry.moodFromScore(data.score.round());
                      return LineTooltipItem(
                        '${DateFormat('MMM d').format(data.date)}\n${MoodEntry.getEmoji(mood)} ${data.score.toStringAsFixed(1)}',
                        TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentEntriesList(ColorScheme colorScheme) {
    if (_recentEntries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No mood entries for this period.',
              style: TextStyle(color: colorScheme.outline),
            ),
          ),
        ),
      );
    }

    final entriesToShow = _recentEntries.reversed.take(10).toList();

    return Column(
      children: entriesToShow.map((entry) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Color(MoodEntry.getColor(entry.mood)).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(MoodEntry.getEmoji(entry.mood), style: const TextStyle(fontSize: 22)),
              ),
            ),
            title: Text(
              '${entry.mood[0].toUpperCase()}${entry.mood.substring(1)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              entry.note.isNotEmpty ? entry.note : 'Score: ${entry.score}/10',
              style: TextStyle(fontSize: 12, color: colorScheme.outline),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormat('MMM d').format(entry.date),
                  style: TextStyle(fontSize: 12, color: colorScheme.outline),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: entry.source == 'chat'
                        ? colorScheme.primaryContainer
                        : colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.source == 'chat' ? 'Auto' : 'Manual',
                    style: TextStyle(
                      fontSize: 10,
                      color: entry.source == 'chat'
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ==================== OVERVIEW TAB ====================

  Widget _buildOverviewTab(ColorScheme colorScheme) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsRow(colorScheme),
            const SizedBox(height: 20),
            Text(
              'Mood Distribution',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Last $_selectedDays days',
              style: TextStyle(color: colorScheme.outline, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _buildPieChart(colorScheme),
            const SizedBox(height: 20),
            Text(
              'Emotion Breakdown',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildEmotionBars(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(ColorScheme colorScheme) {
    final totalEntries = _recentEntries.length;
    final positiveCount = _recentEntries.where((e) => e.isPositive).length;
    final negativeCount = _recentEntries.where((e) => e.isNegative).length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(colorScheme, icon: Icons.analytics, label: 'Entries',
              value: totalEntries.toString(), color: Colors.blue),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(colorScheme, icon: Icons.sentiment_very_satisfied, label: 'Positive',
              value: positiveCount.toString(), color: Colors.green),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(colorScheme, icon: Icons.sentiment_dissatisfied, label: 'Low',
              value: negativeCount.toString(), color: Colors.orange),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(colorScheme, icon: Icons.speed, label: 'Average',
              value: _averageScore.toStringAsFixed(1), color: Colors.purple),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ColorScheme colorScheme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: colorScheme.outline)),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(ColorScheme colorScheme) {
    if (_moodDistribution.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text('No data available', style: TextStyle(color: colorScheme.outline)),
        ),
      );
    }

    final total = _moodDistribution.values.fold<int>(0, (s, v) => s + v);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 220,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 36,
                    sections: _moodDistribution.entries.map((entry) {
                      final percentage = (entry.value / total * 100);
                      return PieChartSectionData(
                        value: entry.value.toDouble(),
                        title: percentage >= 10 ? '${percentage.toStringAsFixed(0)}%' : '',
                        color: Color(MoodEntry.getColor(entry.key)),
                        radius: 50,
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _moodDistribution.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Color(MoodEntry.getColor(entry.key)),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${MoodEntry.getEmoji(entry.key)} ${entry.key[0].toUpperCase()}${entry.key.substring(1)}',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text('${entry.value}', style: TextStyle(fontSize: 12, color: colorScheme.outline)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmotionBars(ColorScheme colorScheme) {
    if (_moodDistribution.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text('No emotion data yet', style: TextStyle(color: colorScheme.outline)),
          ),
        ),
      );
    }

    final total = _moodDistribution.values.fold<int>(0, (s, v) => s + v);
    final sorted = _moodDistribution.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: sorted.map((entry) {
            final progress = entry.value / total;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(MoodEntry.getEmoji(entry.key), style: const TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 76,
                    child: Text(
                      '${entry.key[0].toUpperCase()}${entry.key.substring(1)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 12,
                        color: Color(MoodEntry.getColor(entry.key)),
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 38,
                    child: Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 12, color: colorScheme.outline),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ==================== ACTIVITIES TAB ====================

  Widget _buildActivitiesTab(ColorScheme colorScheme) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 0,
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.tips_and_updates, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _todayMood != null
                            ? 'Based on your ${_todayMood!.mood} mood (${_todayMood!.score}/10), here are activities that might help:'
                            : 'Here are some wellness activities to try:',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Negative pattern warning
            if (_trend == MoodTrend.declining) ...[
              Card(
                elevation: 0,
                color: Colors.orange.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Negative Pattern Detected',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your mood has been trending downward recently. '
                              'Consider trying some of these activities, and remember '
                              "it's okay to reach out for professional help.",
                              style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Activity suggestion cards
            ..._suggestions.map((suggestion) => _buildActivityCard(colorScheme, suggestion)),

            const SizedBox(height: 16),

            // Professional help reminder
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: colorScheme.outline),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'These are wellness suggestions, not medical advice. '
                        'If you\'re struggling, please reach out to a professional.',
                        style: TextStyle(fontSize: 12, color: colorScheme.outline),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(ColorScheme colorScheme, ActivitySuggestion suggestion) {
    final iconMap = <String, IconData>{
      'air': Icons.air,
      'self_improvement': Icons.self_improvement,
      'people': Icons.people,
      'directions_walk': Icons.directions_walk,
      'music_note': Icons.music_note,
      'favorite': Icons.favorite,
      'fitness_center': Icons.fitness_center,
      'brush': Icons.brush,
      'park': Icons.park,
      'edit_note': Icons.edit_note,
      'volunteer_activism': Icons.volunteer_activism,
      'celebration': Icons.celebration,
      'share': Icons.share,
      'accessibility_new': Icons.accessibility_new,
      'sports_martial_arts': Icons.sports_martial_arts,
      'healing': Icons.healing,
    };

    final categoryColorMap = <String, Color>{
      'breathing': Colors.blue,
      'movement': Colors.green,
      'social': Colors.purple,
      'creative': Colors.pink,
      'mindfulness': Colors.teal,
    };

    final icon = iconMap[suggestion.icon] ?? Icons.lightbulb;
    final categoryColor = categoryColorMap[suggestion.category] ?? Colors.blueGrey;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showActivityDetail(context, suggestion, icon, categoryColor),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: categoryColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(suggestion.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(suggestion.description, style: TextStyle(fontSize: 13, color: colorScheme.outline)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  suggestion.category[0].toUpperCase() + suggestion.category.substring(1),
                  style: TextStyle(fontSize: 10, color: categoryColor, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActivityDetail(BuildContext context, ActivitySuggestion suggestion, IconData icon, Color color) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 36),
              ),
              const SizedBox(height: 16),
              Text(suggestion.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                suggestion.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("I'll try this!"),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ==================== MANUAL MOOD LOGGING ====================

  void _showManualMoodDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    int selectedScore = 5;
    String selectedMood = 'neutral';
    final noteController = TextEditingController();

    final moods = ['excellent', 'happy', 'calm', 'neutral', 'stressed', 'anxious', 'sad', 'angry', 'distressed'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('How are you feeling?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // Mood selector grid
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: moods.map((mood) {
                      final isSelected = selectedMood == mood;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedMood = mood;
                            final scoreMap = {
                              'excellent': 10, 'happy': 8, 'calm': 7,
                              'neutral': 5, 'stressed': 4, 'anxious': 3,
                              'sad': 3, 'angry': 3, 'distressed': 1,
                            };
                            selectedScore = scoreMap[mood] ?? 5;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Color(MoodEntry.getColor(mood)).withValues(alpha: 0.2)
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                            border: isSelected
                                ? Border.all(color: Color(MoodEntry.getColor(mood)), width: 2)
                                : null,
                          ),
                          child: Column(
                            children: [
                              Text(MoodEntry.getEmoji(mood), style: const TextStyle(fontSize: 24)),
                              const SizedBox(height: 4),
                              Text(
                                mood[0].toUpperCase() + mood.substring(1),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Score slider
                  Row(
                    children: [
                      const Text('Score: ', style: TextStyle(fontWeight: FontWeight.w500)),
                      Expanded(
                        child: Slider(
                          value: selectedScore.toDouble(),
                          min: 1, max: 10, divisions: 9,
                          label: selectedScore.toString(),
                          onChanged: (val) => setDialogState(() => selectedScore = val.round()),
                        ),
                      ),
                      Text('$selectedScore/10', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Optional note
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Add a note (optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Log Mood'),
                      onPressed: () async {
                        final entry = MoodEntry(
                          id: const Uuid().v4(),
                          mood: selectedMood,
                          score: selectedScore,
                          note: noteController.text.trim(),
                          source: 'manual',
                          date: DateTime.now(),
                        );

                        await _moodService.saveMoodEntry(entry);
                        _firestoreService.saveMoodEntry(entry).catchError(
                          (e) => debugPrint('Firestore mood save error: $e'),
                        );

                        if (context.mounted) Navigator.pop(context);
                        _loadData();
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
