// relax_screen.dart - Relaxation features
// Includes breathing exercise and meditation audio player

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:just_audio/just_audio.dart';

class RelaxScreen extends StatefulWidget {
  const RelaxScreen({super.key});

  @override
  State<RelaxScreen> createState() => _RelaxScreenState();
}

class _RelaxScreenState extends State<RelaxScreen>
    with SingleTickerProviderStateMixin {
  // Tab controller
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relax'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.air), text: 'Breathing'),
            Tab(icon: Icon(Icons.music_note), text: 'Sounds'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _BreathingExerciseTab(),
          _MeditationSoundsTab(),
        ],
      ),
    );
  }
}

// ==================== BREATHING EXERCISE TAB ====================

class _BreathingExerciseTab extends StatefulWidget {
  const _BreathingExerciseTab();

  @override
  State<_BreathingExerciseTab> createState() => _BreathingExerciseTabState();
}

class _BreathingExerciseTabState extends State<_BreathingExerciseTab>
    with TickerProviderStateMixin {
  // Breathing pattern: 4-7-8 technique
  static const int _inhaleSeconds = 4;
  static const int _holdSeconds = 7;
  static const int _exhaleSeconds = 8;

  bool _isRunning = false;
  String _currentPhase = 'Ready';
  int _currentCount = 0;
  int _cyclesCompleted = 0;
  Timer? _timer;

  late AnimationController _breathController;
  late Animation<double> _breathAnimation;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      duration: const Duration(seconds: _inhaleSeconds + _holdSeconds + _exhaleSeconds),
      vsync: this,
    );
    _breathAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breathController.dispose();
    super.dispose();
  }

  void _startBreathing() {
    setState(() {
      _isRunning = true;
      _cyclesCompleted = 0;
    });
    _runCycle();
  }

  void _stopBreathing() {
    _timer?.cancel();
    _breathController.stop();
    setState(() {
      _isRunning = false;
      _currentPhase = 'Ready';
      _currentCount = 0;
    });
  }

  void _runCycle() async {
    if (!_isRunning) return;

    // Inhale phase
    setState(() {
      _currentPhase = 'Inhale';
      _currentCount = _inhaleSeconds;
    });
    _breathController.forward(from: 0.0);

    for (int i = _inhaleSeconds; i > 0; i--) {
      if (!_isRunning) return;
      setState(() => _currentCount = i);
      await Future.delayed(const Duration(seconds: 1));
    }

    // Hold phase
    setState(() {
      _currentPhase = 'Hold';
      _currentCount = _holdSeconds;
    });

    for (int i = _holdSeconds; i > 0; i--) {
      if (!_isRunning) return;
      setState(() => _currentCount = i);
      await Future.delayed(const Duration(seconds: 1));
    }

    // Exhale phase
    setState(() {
      _currentPhase = 'Exhale';
      _currentCount = _exhaleSeconds;
    });
    _breathController.reverse();

    for (int i = _exhaleSeconds; i > 0; i--) {
      if (!_isRunning) return;
      setState(() => _currentCount = i);
      await Future.delayed(const Duration(seconds: 1));
    }

    // Cycle complete
    setState(() => _cyclesCompleted++);

    // Continue if still running
    if (_isRunning) {
      _runCycle();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Info card
          Card(
            elevation: 0,
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '4-7-8 Breathing: Inhale 4s, Hold 7s, Exhale 8s. '
                      'This technique helps reduce anxiety and promote relaxation.',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Breathing circle
          AnimatedBuilder(
            animation: _breathAnimation,
            builder: (context, child) {
              return Container(
                width: 220 * _breathAnimation.value,
                height: 220 * _breathAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.3),
                      colorScheme.primary.withValues(alpha: 0.1),
                    ],
                  ),
                  border: Border.all(
                    color: colorScheme.primary,
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentPhase,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      if (_isRunning) ...[
                        const SizedBox(height: 8),
                        Text(
                          '$_currentCount',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w300,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 40),

          // Cycles completed
          if (_cyclesCompleted > 0)
            Text(
              'Cycles completed: $_cyclesCompleted',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.outline,
              ),
            ),
          const SizedBox(height: 24),

          // Start/Stop button
          SizedBox(
            width: 200,
            height: 56,
            child: FilledButton.icon(
              icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
              label: Text(_isRunning ? 'Stop' : 'Start Breathing'),
              onPressed: _isRunning ? _stopBreathing : _startBreathing,
              style: FilledButton.styleFrom(
                backgroundColor:
                    _isRunning ? colorScheme.error : colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Tips
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tips_and_updates, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Tips for Better Practice',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTip('Find a comfortable seated position'),
                  _buildTip('Close your eyes or soften your gaze'),
                  _buildTip('Breathe through your nose'),
                  _buildTip('Practice for 3-4 cycles to start'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

// ==================== MEDITATION SOUNDS TAB ====================

class _MeditationSoundsTab extends StatefulWidget {
  const _MeditationSoundsTab();

  @override
  State<_MeditationSoundsTab> createState() => _MeditationSoundsTabState();
}

class _MeditationSoundsTabState extends State<_MeditationSoundsTab> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlaying;

  // Sound options with asset paths
  final List<Map<String, dynamic>> _sounds = [
    {
      'name': 'Rain',
      'icon': Icons.water_drop,
      'color': Colors.blue,
      'asset': 'assets/audio/rain.mp3',
    },
    {
      'name': 'Ocean Waves',
      'icon': Icons.waves,
      'color': Colors.teal,
      'asset': 'assets/audio/ocean.mp3',
    },
    {
      'name': 'Forest',
      'icon': Icons.forest,
      'color': Colors.green,
      'asset': 'assets/audio/forest.mp3',
    },
    {
      'name': 'Fireplace',
      'icon': Icons.local_fire_department,
      'color': Colors.orange,
      'asset': 'assets/audio/fireplace.mp3',
    },
    {
      'name': 'Wind',
      'icon': Icons.air,
      'color': Colors.grey,
      'asset': 'assets/audio/wind.mp3',
    },
    {
      'name': 'Birds',
      'icon': Icons.flutter_dash,
      'color': Colors.amber,
      'asset': 'assets/audio/birds.mp3',
    },
  ];

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSound(String name, String asset) async {
    // If same sound is playing, stop it
    if (_currentlyPlaying == name) {
      await _stopAll();
      return;
    }

    try {
      // Stop any current sound first
      await _audioPlayer.stop();

      // Update state immediately to show selection
      setState(() => _currentlyPlaying = name);

      // Load and play new sound
      await _audioPlayer.setAsset(asset);
      _audioPlayer.setLoopMode(LoopMode.one);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Audio error: $e');
      setState(() => _currentlyPlaying = null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not play: $name'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _stopAll() async {
    await _audioPlayer.stop();
    setState(() => _currentlyPlaying = null);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Card(
            elevation: 0,
            color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.headphones, color: colorScheme.secondary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Tap a sound to play. Tap again to stop.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Currently playing indicator with stop button
          if (_currentlyPlaying != null) ...[
            Card(
              color: colorScheme.primaryContainer,
              child: ListTile(
                leading: Icon(Icons.music_note, color: colorScheme.primary),
                title: Text(_currentlyPlaying!, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Now Playing'),
                trailing: FilledButton.icon(
                  onPressed: _stopAll,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Sound grid
          Text(
            'Relaxation Sounds',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: _sounds.map((sound) {
              final isPlaying = _currentlyPlaying == sound['name'];
              return _SimpleSoundCard(
                name: sound['name'],
                icon: sound['icon'],
                color: sound['color'],
                isPlaying: isPlaying,
                onTap: () => _playSound(sound['name'], sound['asset']),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Note about adding audio files
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
                      'Add your own audio files to assets/audio/ folder '
                      'and update pubspec.yaml to include them.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Simplified sound card widget
class _SimpleSoundCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final bool isPlaying;
  final VoidCallback onTap;

  const _SimpleSoundCard({
    required this.name,
    required this.icon,
    required this.color,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isPlaying ? 4 : 1,
      color: isPlaying ? color.withValues(alpha: 0.2) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: isPlaying ? Border.all(color: color, width: 2) : null,
                ),
                child: Icon(
                  isPlaying ? Icons.pause : icon,
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                style: TextStyle(
                  fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                  color: isPlaying ? color : null,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}