import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/header_widgets.dart';

class ShareScreen extends StatelessWidget {
  const ShareScreen({super.key});

  void _shareInviteLink() {
    Share.share(
        'Join me on TeamBuild Pro: https://teambuildpro.com/invite/abc123');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const AppHeaderWithMenu(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'Share Your Link',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Your referral link will appear here.'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Share Invite'),
                    onPressed: _shareInviteLink,
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
