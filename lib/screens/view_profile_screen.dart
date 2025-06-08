import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ViewProfileScreen extends StatelessWidget {
  final String name;
  final String city;
  final String state;
  final String country;
  final String? avatarUrl;
  final String? joinDateString;
  final bool isDirectDownline;

  const ViewProfileScreen({
    super.key,
    required this.name,
    required this.city,
    required this.state,
    required this.country,
    required this.joinDateString,
    required this.isDirectDownline,
    this.avatarUrl,
  });

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cityState = [city, state].where((s) => s.isNotEmpty).join(', ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl!) : null,
              child:
                  avatarUrl == null ? const Icon(Icons.person, size: 50) : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (cityState.isNotEmpty)
            Text(
              cityState,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          Text(
            country,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (_formatDate(joinDateString).isNotEmpty)
            Text(
              'Joined: ${_formatDate(joinDateString)}',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 24),
          if (isDirectDownline)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const PlaceholderScreen(title: 'Message Center'),
                    ),
                  );
                },
                icon: const Icon(Icons.message),
                label: const Text('Message Center'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Text(
          '🚧 This feature is under construction.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
