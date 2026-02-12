// help_screen.dart - Mental Health Resources and Hotlines
// Focused on Sri Lankan resources with emergency contact features

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Resources'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emergency button
            _EmergencyButton(colorScheme: colorScheme),
            const SizedBox(height: 24),

            // Sri Lankan Hotlines
            Text(
              'Sri Lankan Mental Health Hotlines',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _HotlineCard(
              name: 'Sumithrayo',
              description: '24/7 emotional support & suicide prevention',
              phone: '011-2682535',
              additionalPhone: '011-2683252',
              colorScheme: colorScheme,
            ),
            _HotlineCard(
              name: 'CCC Line (1333)',
              description: 'National helpline for counseling support',
              phone: '1333',
              colorScheme: colorScheme,
            ),
            _HotlineCard(
              name: 'Shanthi Maargam',
              description: 'Mental health support & guidance',
              phone: '0717-639898',
              colorScheme: colorScheme,
            ),
            _HotlineCard(
              name: 'National Mental Health Helpline',
              description: 'Government mental health support',
              phone: '1926',
              colorScheme: colorScheme,
            ),
            _HotlineCard(
              name: 'Women In Need (WIN)',
              description: 'Support for women facing abuse or distress',
              phone: '011-2671411',
              additionalPhone: '011-4718585',
              colorScheme: colorScheme,
            ),
            _HotlineCard(
              name: 'Childline Sri Lanka',
              description: 'Support for children and young people',
              phone: '1929',
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 24),

            // International resources
            Text(
              'International Resources',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _HotlineCard(
              name: 'International Association for Suicide Prevention',
              description: 'Find resources worldwide',
              phone: 'Visit: iasp.info/resources',
              isWebsite: true,
              website: 'https://www.iasp.info/resources/Crisis_Centres/',
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 24),

            // Self-help resources
            Text(
              'Self-Help Resources',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _ResourceCard(
              title: 'Grounding Techniques',
              description:
                  'When feeling overwhelmed, try the 5-4-3-2-1 technique: '
                  'Name 5 things you see, 4 you can touch, 3 you hear, '
                  '2 you smell, and 1 you taste.',
              icon: Icons.self_improvement,
              colorScheme: colorScheme,
            ),
            _ResourceCard(
              title: 'Breathing Exercise',
              description:
                  'Try 4-7-8 breathing: Inhale for 4 seconds, hold for 7 seconds, '
                  'exhale for 8 seconds. Repeat 3-4 times.',
              icon: Icons.air,
              colorScheme: colorScheme,
            ),
            _ResourceCard(
              title: 'Reach Out',
              description:
                  "It's okay to ask for help. Talk to someone you trust - "
                  'a friend, family member, or professional.',
              icon: Icons.people,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 24),

            // Disclaimer
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: colorScheme.outline,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This app provides general wellness support and is not a '
                        'substitute for professional mental health care. If you '
                        "are in crisis, please contact emergency services or a "
                        'crisis hotline immediately.',
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// Emergency help button
class _EmergencyButton extends StatelessWidget {
  final ColorScheme colorScheme;

  const _EmergencyButton({required this.colorScheme});

  Future<void> _callEmergency(BuildContext context) async {
    // Show confirmation dialog
    final shouldCall = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red),
            SizedBox(width: 8),
            Text('Call Sumithrayo?'),
          ],
        ),
        content: const Text(
          'You are about to call Sumithrayo (011-2682535), '
          "Sri Lanka's 24/7 emotional support helpline.\n\n"
          'They are here to listen and help.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Call Now'),
          ),
        ],
      ),
    );

    if (shouldCall == true) {
      final Uri phoneUri = Uri(scheme: 'tel', path: '0112682535');
      try {
        if (await canLaunchUrl(phoneUri)) {
          await launchUrl(phoneUri);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not open phone app. Number: 011-2682535'),
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open phone app. Number: 011-2682535'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      elevation: 2,
      child: InkWell(
        onTap: () => _callEmergency(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_in_talk,
                  color: Colors.red,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'I Need Help Now',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to call Sumithrayo 24/7 helpline',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.red,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Hotline card widget
class _HotlineCard extends StatelessWidget {
  final String name;
  final String description;
  final String phone;
  final String? additionalPhone;
  final bool isWebsite;
  final String? website;
  final ColorScheme colorScheme;

  const _HotlineCard({
    required this.name,
    required this.description,
    required this.phone,
    this.additionalPhone,
    this.isWebsite = false,
    this.website,
    required this.colorScheme,
  });

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied: $text'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _makeCall(BuildContext context, String number) async {
    // Clean the number for dialing
    final cleanNumber = number.replaceAll(RegExp(r'[^0-9]'), '');
    final Uri phoneUri = Uri(scheme: 'tel', path: cleanNumber);

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (context.mounted) {
          _copyToClipboard(context, number);
        }
      }
    } catch (e) {
      if (context.mounted) {
        _copyToClipboard(context, number);
      }
    }
  }

  Future<void> _openWebsite(BuildContext context) async {
    if (website == null) return;

    final Uri uri = Uri.parse(website!);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not open website: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                color: colorScheme.outline,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            if (isWebsite)
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Visit Website'),
                onPressed: () => _openWebsite(context),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PhoneButton(
                    phone: phone,
                    onCall: () => _makeCall(context, phone),
                    onCopy: () => _copyToClipboard(context, phone),
                    colorScheme: colorScheme,
                  ),
                  if (additionalPhone != null)
                    _PhoneButton(
                      phone: additionalPhone!,
                      onCall: () => _makeCall(context, additionalPhone!),
                      onCopy: () => _copyToClipboard(context, additionalPhone!),
                      colorScheme: colorScheme,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// Phone button widget
class _PhoneButton extends StatelessWidget {
  final String phone;
  final VoidCallback onCall;
  final VoidCallback onCopy;
  final ColorScheme colorScheme;

  const _PhoneButton({
    required this.phone,
    required this.onCall,
    required this.onCopy,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onCall,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.phone, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    phone,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: colorScheme.outline.withValues(alpha: 0.2),
          ),
          InkWell(
            onTap: onCopy,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Icon(Icons.copy, size: 16, color: colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// Self-help resource card
class _ResourceCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final ColorScheme colorScheme;

  const _ResourceCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colorScheme.secondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}