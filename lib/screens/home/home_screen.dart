// home_screen.dart - Main home screen with overview
// Shows welcome message and quick actions

import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final userEmail = authService.currentUser?.email ?? 'User';
    // Get first part of email as username
    final username = userEmail.split('@').first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Mental Wellness'),
        actions: [
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              // Show confirmation dialog
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );

              if (shouldLogout == true) {
                await authService.logout();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome message
            Text(
              'Hello, $username! 👋',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'How are you feeling today?',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),

            // Quick Actions Grid
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            // Grid of action cards
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _buildActionCard(
                  context,
                  icon: Icons.book,
                  title: 'Write Journal',
                  subtitle: 'Express your thoughts',
                  color: Colors.blue,
                  onTap: () {
                    // Navigate to journal tab (index 1)
                    // We'll use a callback or state management later
                  },
                ),
                _buildActionCard(
                  context,
                  icon: Icons.chat,
                  title: 'Talk to AI',
                  subtitle: 'Get support',
                  color: Colors.green,
                  onTap: () {},
                ),
                _buildActionCard(
                  context,
                  icon: Icons.spa,
                  title: 'Relax',
                  subtitle: 'Breathing & sounds',
                  color: Colors.purple,
                  onTap: () {},
                ),
                _buildActionCard(
                  context,
                  icon: Icons.insert_chart,
                  title: 'View Mood',
                  subtitle: 'Track progress',
                  color: Colors.orange,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Daily tip card
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Daily Wellness Tip',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Take a few minutes to practice deep breathing. '
                      'Inhale for 4 seconds, hold for 4 seconds, '
                      'and exhale for 4 seconds. This can help reduce stress and anxiety.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Motivational quote
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.format_quote,
                      size: 32,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"The greatest glory in living lies not in never falling, '
                      'but in rising every time we fall."',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '- Nelson Mandela',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
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

  // Helper method to build action cards
  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
