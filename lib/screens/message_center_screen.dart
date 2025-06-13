// message_center_screen.dart (Corrected)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import '../widgets/header_widgets.dart';
import '../services/session_manager.dart';
import '../services/firestore_service.dart';
import 'message_thread_screen.dart';
import '../services/subscription_service.dart';
import '../models/user_model.dart';

class MessageCenterScreen extends StatefulWidget {
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
  final Map<String, UserModel> _usersInThreads = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentUserAndCheckSubscription();
  }

  Future<void> _loadCurrentUserAndCheckSubscription() async {
    final user = await _sessionManager.getCurrentUser();

    if (user != null && user.role == 'admin') {
      final status =
          await SubscriptionService.checkAdminSubscriptionStatus(user.uid);
      final isActive = status['isActive'] == true;

      if (!isActive) {
        if (!mounted) return;
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
                  Navigator.of(context).pop();
                  Navigator.pushNamed(context, '/upgrade');
                },
                child: const Text('Upgrade Now'),
              ),
            ],
          ),
        );
        return;
      }
    }

    if (mounted && user != null) {
      setState(() {
        _currentUserId = user.uid;
        _usersInThreads[user.uid] = user;
      });
    }
  }

  Future<List<QueryDocumentSnapshot>> _getInboxThreads() async {
    if (_currentUserId == null) {
      return [];
    }
    // MODIFIED: Order threads by the new 'lastUpdatedAt' field to show recent chats first.
    final snapshot = await FirebaseFirestore.instance
        .collection('messages')
        .where('allowedUsers', arrayContains: _currentUserId)
        .orderBy('lastUpdatedAt', descending: true)
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
    final uidsToFetch =
        uids.where((uid) => !_usersInThreads.containsKey(uid)).toList();

    if (uidsToFetch.isEmpty) return;

    final futures = uidsToFetch.map((uid) async {
      final user = await _firestoreService.getUser(uid);
      if (user != null) {
        if (mounted) {
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
      appBar: AppHeaderWithMenu(
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
                          debugPrint(
                              'Error fetching inbox threads: ${snapshot.error}');
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final threads = snapshot.data ?? [];
                        final userThreads = threads.where((doc) {
                          final id = doc.id;
                          return id.contains(_currentUserId!);
                        }).toList();

                        final otherUserIds = userThreads
                            .map((doc) => _getOtherUserId(doc.id))
                            .where((id) => id.isNotEmpty)
                            .toSet()
                            .toList();

                        return FutureBuilder(
                          future: _fetchUsersInThreads(otherUserIds),
                          builder: (context, userSnapshot) {
                            if (userSnapshot.connectionState ==
                                    ConnectionState.waiting &&
                                userThreads.isNotEmpty) {
                              // Show a loader only if we are still fetching users but have threads
                              return const Center(
                                  child: CircularProgressIndicator());
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
                                final data = doc.data() as Map<String, dynamic>;
                                final threadId = doc.id;
                                final otherUserId = _getOtherUserId(threadId);
                                final otherUser = _usersInThreads[otherUserId];

                                final otherUserName = otherUser != null
                                    ? '${otherUser.firstName ?? ''} ${otherUser.lastName ?? ''}'
                                        .trim()
                                    : otherUserId;
                                final photoUrl = otherUser?.photoUrl;

                                // --- NEW: Logic for message snippet ---
                                String lastMessage = data['lastMessage'] ?? '';
                                String snippet = lastMessage;
                                if (lastMessage.length > 35) {
                                  snippet =
                                      '${lastMessage.substring(0, 35)}...';
                                }
                                if (data['lastMessageSenderId'] ==
                                    _currentUserId) {
                                  snippet = 'You: $snippet';
                                }

                                // --- NEW: Logic for timestamp ---
                                final timestamp =
                                    data['lastUpdatedAt'] as Timestamp?;
                                final timeStr = timestamp != null
                                    ? DateFormat.jm().format(timestamp.toDate())
                                    : '';

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: (photoUrl != null &&
                                            photoUrl.isNotEmpty)
                                        ? NetworkImage(photoUrl)
                                        : null,
                                    child:
                                        (photoUrl == null || photoUrl.isEmpty)
                                            ? const Icon(Icons.person_outline)
                                            : null,
                                  ),
                                  title: Text(otherUserName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  // MODIFIED: Added subtitle for the snippet
                                  subtitle: Text(snippet),
                                  // MODIFIED: Added trailing for the timestamp
                                  trailing: Text(timeStr),
                                  onTap: () {
                                    if (!mounted) {
                                      return;
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MessageThreadScreen(
                                          threadId: threadId,
                                          firebaseConfig: widget.firebaseConfig,
                                          initialAuthToken:
                                              widget.initialAuthToken,
                                          appId: widget.appId,
                                          recipientId: otherUserId,
                                          recipientName: otherUserName,
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
