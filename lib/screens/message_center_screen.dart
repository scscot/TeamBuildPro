// FINAL PATCH — MessageCenterScreen as Inbox-Only View (with Full Name & Profile Pics)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/header_widgets.dart';
import '../services/session_manager.dart';
import '../services/firestore_service.dart';
import 'message_thread_screen.dart';
import '../services/subscription_service.dart';

class MessageCenterScreen extends StatefulWidget {
  const MessageCenterScreen({super.key});

  @override
  State<MessageCenterScreen> createState() => _MessageCenterScreenState();
}

class _MessageCenterScreenState extends State<MessageCenterScreen> {
  final currentUser = SessionManager.instance;
  final firestoreService = FirestoreService();

  String? _currentUserId;
  final Map<String, String> _userNames = {}; // uid -> full name
  final Map<String, String> _userPhotos = {}; // uid -> photo URL

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await currentUser.getCurrentUser();

    // PATCH START — Subscription check for Admin users
    if (user != null && user.role == 'admin') {
      final status =
          await SubscriptionService.checkAdminSubscriptionStatus(user.uid);
      final isActive = status['isActive'] == true;

      if (!isActive && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Subscription Required'),
            content: const Text(
                'To access the Message Center, your Admin subscription must be active.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/upgrade'),
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
      setState(() => _currentUserId = user.uid);
    }
  }

  Future<List<QueryDocumentSnapshot>> _getInboxThreads() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('messages').get();
    return snapshot.docs;
  }

  String _getOtherUserId(String threadId) {
    final ids = threadId.split('_');
    return (ids.length == 2 && _currentUserId != null)
        ? (ids[0] == _currentUserId ? ids[1] : ids[0])
        : '';
  }

  Future<void> _fetchNamesAndPhotos(List<String> uids) async {
    final futures = uids.map((uid) async {
      if (!_userNames.containsKey(uid)) {
        final user = await firestoreService.getUser(uid);
        if (user != null) {
          _userNames[uid] = '${user.firstName} ${user.lastName}';
          _userPhotos[uid] = user.photoUrl ?? '';
        }
      }
    });
    await Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeaderWithMenu(),
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
                          return Text('Error: ${snapshot.error}');
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
                          future: _fetchNamesAndPhotos(otherUserIds),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
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
                                final threadId = doc.id;
                                final otherUserId = _getOtherUserId(threadId);
                                final otherUserName =
                                    _userNames[otherUserId] ?? otherUserId;
                                final photoUrl = _userPhotos[otherUserId];

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
                                  title: Text(otherUserName),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MessageThreadScreen(
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
