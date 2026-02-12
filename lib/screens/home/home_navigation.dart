// home_navigation.dart - Main navigation with bottom nav bar
// Contains 6 screens: Home, Journal, Chat, Mood, Relax, Help

import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../journal/journal_screen.dart';
import '../chat/chat_screen.dart';
import '../mood/mood_screen.dart';
import '../relax/relax_screen.dart';
import '../help/help_screen.dart';

class HomeNavigation extends StatefulWidget {
  const HomeNavigation({super.key});

  @override
  State<HomeNavigation> createState() => _HomeNavigationState();
}

class _HomeNavigationState extends State<HomeNavigation> {
  // Current selected tab index
  int _currentIndex = 0;

  // List of all screens
  final List<Widget> _screens = [
    const HomeScreen(),
    const JournalScreen(),
    const ChatScreen(),
    const MoodScreen(),
    const RelaxScreen(),
    const HelpScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Display current screen
      body: _screens[_currentIndex],

      // Bottom navigation bar
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          // Home tab
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          // Journal tab
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'Journal',
          ),
          // Chat tab
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Chat',
          ),
          // Mood tab
          NavigationDestination(
            icon: Icon(Icons.insert_chart_outlined),
            selectedIcon: Icon(Icons.insert_chart),
            label: 'Mood',
          ),
          // Relax tab
          NavigationDestination(
            icon: Icon(Icons.spa_outlined),
            selectedIcon: Icon(Icons.spa),
            label: 'Relax',
          ),
          // Help tab
          NavigationDestination(
            icon: Icon(Icons.help_outline),
            selectedIcon: Icon(Icons.help),
            label: 'Help',
          ),
        ],
      ),
    );
  }
}
