import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/header_widgets.dart';
// Note: Removed unused Firebase/UserModel imports as they are no longer needed in this simplified version.

class ShareScreen extends StatelessWidget {
  // Add required parameters to ShareScreen constructor
  // final Map<String, dynamic> firebaseConfig;
  final String? initialAuthToken;
  final String appId;

  const ShareScreen({
    super.key,
    // required this.firebaseConfig,
    this.initialAuthToken,
    required this.appId,
  });

  void _shareInviteLink() {
    Share.share(
        'Join me on TeamBuild Pro: https://teambuildpro.com/invite/abc123'); // Your preferred hardcoded link
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeaderWithMenu(
        // Pass required args to the header
        // firebaseConfig: firebaseConfig,
        initialAuthToken: initialAuthToken,
        appId: appId,
      ),
      body: Column(
        children: [
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
                  const Text(
                      'Your referral link will appear here.'), // Retaining this text as per your original
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
