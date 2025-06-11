// FINAL PATCH — MessageCenterScreen as Inbox-Only View (with Full Name & Profile Pics)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // Import for FirebaseAuth
import '../widgets/header_widgets.dart';
import '../services/session_manager.dart';
import '../services/firestore_service.dart';
import 'message_thread_screen.dart';
import '../services/subscription_service.dart';
import '../models/user_model.dart'; // Ensure UserModel is imported for user.role, etc.

class MessageCenterScreen extends StatefulWidget {
  // Add required parameters to MessageCenterScreen constructor
  final Map<String, dynamic> firebaseConfig;
  final String? initialAuthToken;
  final String appId;

  const MessageCenterScreen({
    super.key,
    required this.firebaseConfig,
    this.initialAuthToken,
    required this.appId,
  });

  @override
  State<MessageCenterScreen> createState() => _MessageCenterScreenState();
}

class _MessageCenterScreenState extends State<MessageCenterScreen> {
  final SessionManager _sessionManager = SessionManager();
  final FirestoreService _firestoreService = FirestoreService();

  String? _currentUserId;
  final Map<String, UserModel> _usersInThreads = {}; // uid -> UserModel

  @override
  void initState() {
    super.initState();
    _loadCurrentUserAndCheckSubscription();
  }

  Future<void> _loadCurrentUserAndCheckSubscription() async {
    final user = await _sessionManager.getCurrentUser();

    // PATCH START — Subscription check for Admin users
    if (user != null && user.role == 'admin') {
      final status =
          await SubscriptionService.checkAdminSubscriptionStatus(user.uid);
      final isActive = status['isActive'] == true;

      if (!isActive) {
        if (!mounted) return; // Guarded context usage
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Subscription Required'),
            content: const Text(
                'To access the Message Center, your Admin subscription must be active.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Pop the dialog first
                  Navigator.pushNamed(context, '/upgrade');
                },
                child: const Text('Upgrade Now'),
              ),
            ],
          ),
        );
        return; // block loading threads
      }
    }
    // PATCH END

    if (mounted && user != null) {
      setState(() {
        _currentUserId = user.uid;
        _usersInThreads[user.uid] = user; // Add current user to map
      });
    }
  }

  Future<List<QueryDocumentSnapshot>> _getInboxThreads() async {
    if (_currentUserId == null) {
      return []; // Return empty if current user ID is not loaded yet
    }
    // Query for threads where the current user is a participant.
    // Assuming 'allowedUsers' is an array on the message thread document that contains participant UIDs.
    final snapshot = await FirebaseFirestore.instance
        .collection('messages')
        .where('allowedUsers', arrayContains: _currentUserId)
        .get();
    return snapshot.docs;
  }

  String _getOtherUserId(String threadId) {
    final ids = threadId.split('_');
    return (ids.length == 2 && _currentUserId != null)
        ? (ids[0] == _currentUserId ? ids[1] : ids[0])
        : '';
  }

  Future<void> _fetchUsersInThreads(List<String> uids) async {
    // Filter out UIDs already fetched to avoid redundant calls
    final uidsToFetch = uids.where((uid) => !_usersInThreads.containsKey(uid)).toList();

    if (uidsToFetch.isEmpty) return;

    // Firestore `whereIn` queries are limited to 10. You might need to batch these.
    // For this example, assuming a small number of participants per conversation.
    final futures = uidsToFetch.map((uid) async {
      final user = await _firestoreService.getUser(uid);
      if (user != null) {
        if (mounted) { // Guarded setState
          setState(() {
            _usersInThreads[user.uid] = user;
          });
        }
      }
    });
    await Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeaderWithMenu( // Pass required args to AppHeaderWithMenu
        firebaseConfig: widget.firebaseConfig,
        initialAuthToken: widget.initialAuthToken,
        appId: widget.appId,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 24.0),
              child: Center(
                child: Text(
                  'Message Center',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: (_currentUserId == null)
                  ? const Center(child: CircularProgressIndicator())
                  : FutureBuilder<List<QueryDocumentSnapshot>>(
                      future: _getInboxThreads(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          debugPrint('Error fetching inbox threads: ${snapshot.error}');
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final threads = snapshot.data ?? [];
                        // Filter threads to only show ones involving the current user directly
                        // (Assuming thread IDs are structured like uid1_uid2)
                        final userThreads = threads.where((doc) {
                          final id = doc.id;
                          return id.contains(_currentUserId!);
                        }).toList();

                        // Extract all unique other user IDs involved in conversations
                        final otherUserIds = userThreads
                            .map((doc) => _getOtherUserId(doc.id))
                            .where((id) => id.isNotEmpty)
                            .toSet() // Use toSet to get unique UIDs
                            .toList();

                        return FutureBuilder(
                          future: _fetchUsersInThreads(otherUserIds),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            if (userThreads.isEmpty) {
                              return const Center(
                                child: Text('📫 No conversations yet.',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500)),
                              );
                            }

                            return ListView.builder(
                              itemCount: userThreads.length,
                              itemBuilder: (context, index) {
                                final doc = userThreads[index];
                                final threadId = doc.id;
                                final otherUserId = _getOtherUserId(threadId);
                                final otherUser = _usersInThreads[otherUserId]; // Get full UserModel

                                final otherUserName = otherUser != null
                                    ? '${otherUser.firstName ?? ''} ${otherUser.lastName ?? ''}'.trim()
                                    : otherUserId; // Fallback to UID if name not found
                                final photoUrl = otherUser?.photoUrl; // Null-aware access for photoUrl

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                                        ? NetworkImage(photoUrl)
                                        : null,
                                    child: (photoUrl == null || photoUrl.isEmpty)
                                            ? const Icon(Icons.person_outline)
                                            : null,
                                  ),
                                  title: Text(otherUserName),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    if (!mounted) return; // Guarded context usage
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MessageThreadScreen(
                                          threadId: threadId, // Pass the threadId
                                          // Now, pass all required args to MessageThreadScreen
                                          firebaseConfig: widget.firebaseConfig,
                                          initialAuthToken: widget.initialAuthToken,
                                          appId: widget.appId,
                                          recipientId: otherUserId, // Pass recipient's UID
                                          recipientName: otherUserName, // Pass recipient's full name
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
