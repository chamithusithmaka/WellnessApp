// journal_screen.dart - Journal feature with CRUD operations
// Uses Firebase Firestore for storage

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/journal_entry.dart';
import '../../services/firestore_service.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  List<JournalEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  // Load entries from Firestore
  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    try {
      final entries = await _firestoreService.getAllJournalEntries();
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Journal: Error loading entries: $e');
      setState(() => _isLoading = false);
    }
  }

  // Add new journal entry
  Future<void> _addEntry(String text, String emotion) async {
    final entry = JournalEntry(
      id: const Uuid().v4(),
      text: text,
      emotion: emotion,
      date: DateTime.now(),
      isSynced: true, // Always synced since we're using Firestore
    );

    try {
      await _firestoreService.syncJournalEntry(entry);
      await _loadEntries();
    } catch (e) {
      debugPrint('Journal: Error adding entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save entry: $e')),
        );
      }
    }
  }

  // Update existing entry
  Future<void> _updateEntry(JournalEntry entry, String text, String emotion) async {
    final updated = entry.copyWith(
      text: text,
      emotion: emotion,
    );

    try {
      await _firestoreService.syncJournalEntry(updated);
      await _loadEntries();
    } catch (e) {
      debugPrint('Journal: Error updating entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update entry: $e')),
        );
      }
    }
  }

  // Delete entry
  Future<void> _deleteEntry(JournalEntry entry) async {
    try {
      await _firestoreService.deleteJournalEntry(entry.id);
      await _loadEntries();
    } catch (e) {
      debugPrint('Journal: Error deleting entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete entry: $e')),
        );
      }
    }
  }

  // Helper to get emoji for emotion
  String _getEmoji(String emotion) {
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

  // Helper to get color for emotion
  Color _getColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return const Color(0xFF4CAF50); // Green
      case 'calm':
        return const Color(0xFF2196F3); // Blue
      case 'sad':
        return const Color(0xFF9E9E9E); // Grey
      case 'anxious':
        return const Color(0xFFFF9800); // Orange
      case 'angry':
        return const Color(0xFFF44336); // Red
      case 'stressed':
        return const Color(0xFF9C27B0); // Purple
      case 'grateful':
        return const Color(0xFFE91E63); // Pink
      case 'hopeful':
        return const Color(0xFFFFEB3B); // Yellow
      default:
        return const Color(0xFF607D8B); // Blue Grey
    }
  }

  // Show add/edit dialog
  void _showEntryDialog({JournalEntry? entry}) {
    final isEditing = entry != null;
    final textController = TextEditingController(text: entry?.text ?? '');
    String selectedEmotion = entry?.emotion ?? 'calm';

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
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    isEditing ? 'Edit Entry' : 'New Journal Entry',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Emotion selector
                  const Text(
                    'How are you feeling?',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: Emotions.list.map((emotion) {
                      final isSelected = selectedEmotion == emotion;
                      final emotionColor = _getColor(emotion);
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() => selectedEmotion = emotion);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? emotionColor.withValues(alpha: 0.2)
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                            border: isSelected
                                ? Border.all(
                                    color: emotionColor,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _getEmoji(emotion),
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                emotion[0].toUpperCase() + emotion.substring(1),
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Text input
                  TextField(
                    controller: textController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Write your thoughts here...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: Icon(isEditing ? Icons.save : Icons.add),
                      label: Text(isEditing ? 'Save Changes' : 'Add Entry'),
                      onPressed: () {
                        final text = textController.text.trim();
                        if (text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please write something'),
                            ),
                          );
                          return;
                        }

                        if (isEditing) {
                          _updateEntry(entry, text, selectedEmotion);
                        } else {
                          _addEntry(text, selectedEmotion);
                        }

                        Navigator.pop(context);
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

  // Confirm delete dialog
  void _confirmDelete(JournalEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text(
          'Are you sure you want to delete this journal entry? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteEntry(entry);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _buildEmptyState(colorScheme)
              : _buildEntryList(colorScheme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEntryDialog(),
        icon: const Icon(Icons.edit),
        label: const Text('New Entry'),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book_outlined,
            size: 80,
            color: colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No journal entries yet',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: colorScheme.outline),
          ),
          const SizedBox(height: 8),
          Text(
            'Start writing your thoughts!',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryList(ColorScheme colorScheme) {
    return RefreshIndicator(
      onRefresh: _loadEntries,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          final entry = _entries[index];
          return _JournalEntryCard(
            entry: entry,
            colorScheme: colorScheme,
            getEmoji: _getEmoji,
            getColor: _getColor,
            onTap: () => _showEntryDialog(entry: entry),
            onDelete: () => _confirmDelete(entry),
          );
        },
      ),
    );
  }
}

// Journal entry card widget
class _JournalEntryCard extends StatelessWidget {
  final JournalEntry entry;
  final ColorScheme colorScheme;
  final String Function(String) getEmoji;
  final Color Function(String) getColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _JournalEntryCard({
    required this.entry,
    required this.colorScheme,
    required this.getEmoji,
    required this.getColor,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final emotionColor = getColor(entry.emotion);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Emotion badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: emotionColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          getEmoji(entry.emotion),
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          entry.emotion[0].toUpperCase() +
                              entry.emotion.substring(1),
                          style: TextStyle(
                            color: emotionColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Date
                  Text(
                    DateFormat('MMM d, yyyy • h:mm a').format(entry.date),
                    style: TextStyle(
                      color: colorScheme.outline,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Entry text
              Text(
                entry.text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 12),

              // Footer row
              Row(
                children: [
                  // Cloud sync indicator
                  Icon(
                    Icons.cloud_done,
                    size: 16,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Synced',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                    ),
                  ),
                  const Spacer(),
                  // Delete button
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: colorScheme.error,
                      size: 20,
                    ),
                    onPressed: onDelete,
                    tooltip: 'Delete',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}