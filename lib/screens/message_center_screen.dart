import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/header_widgets.dart';
import '../services/session_manager.dart';
import '../services/firestore_service.dart';
import 'message_thread_screen.dart';
import '../services/subscription_service.dart';
import '../models/user_model.dart';

class MessageCenterScreen extends StatefulWidget {
  final String? initialAuthToken;
  final String appId;

  const MessageCenterScreen({
    super.key,
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
  Stream<List<QueryDocumentSnapshot>>? _threadsStream;
  final Map<String, UserModel> _usersInThreads = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentUserAndCheckSubscription();
  }

  Future<void> _loadCurrentUserAndCheckSubscription() async {
    final user = await _sessionManager.getCurrentUser();
    if (user == null) return;

    if (user.role == 'admin') {
      final status =
          await SubscriptionService.checkAdminSubscriptionStatus(user.uid);
      final isActive = status['isActive'] == true;
      if (!mounted) return;
      if (!isActive) {
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
                  child: const Text('Upgrade Now')),
            ],
          ),
        );
        return;
      }
    }

    if (mounted) {
      setState(() {
        _currentUserId = user.uid;
        _usersInThreads[user.uid] = user;
        _threadsStream = FirebaseFirestore.instance
            .collection('messages')
            .where('allowedUsers', arrayContains: user.uid)
            .orderBy('lastUpdatedAt', descending: true)
            .snapshots()
            .map((snapshot) => snapshot.docs);
      });
    }
  }

  String _getOtherUserId(String threadId) {
    if (_currentUserId == null) return '';
    final ids = threadId.split('_');
    return (ids.length == 2)
        ? (ids[0] == _currentUserId ? ids[1] : ids[0])
        : '';
  }

  Future<void> _fetchUserDataForThread(DocumentSnapshot doc) async {
    final otherUserId = _getOtherUserId(doc.id);
    if (otherUserId.isNotEmpty && !_usersInThreads.containsKey(otherUserId)) {
      final user = await _firestoreService.getUser(otherUserId);
      if (user != null && mounted) {
        setState(() {
          _usersInThreads[otherUserId] = user;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeaderWithMenu(
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
                child: Text('Message Center',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: (_currentUserId == null || _threadsStream == null)
                  ? const Center(child: CircularProgressIndicator())
                  : StreamBuilder<List<QueryDocumentSnapshot>>(
                      stream: _threadsStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final threads = snapshot.data ?? [];
                        if (threads.isEmpty) {
                          return const Center(
                              child: Text('📫 No conversations yet.'));
                        }

                        return ListView.builder(
                          itemCount: threads.length,
                          itemBuilder: (context, index) {
                            final doc = threads[index];
                            _fetchUserDataForThread(doc);

                            final data = doc.data() as Map<String, dynamic>;
                            final threadId = doc.id;
                            final otherUserId = _getOtherUserId(threadId);
                            final otherUser = _usersInThreads[otherUserId];

                            final otherUserName = otherUser != null
                                ? '${otherUser.firstName} ${otherUser.lastName}'
                                    .trim()
                                : '...';
                            final photoUrl = otherUser?.photoUrl;

                            // --- THIS IS THE DEFINITIVE FIX ---
                            // It safely handles both Map and String types for 'lastMessage'.
                            final lastMessageValue = data['lastMessage'];
                            String snippet;
                            String lastMessageSenderId;

                            if (lastMessageValue is Map<String, dynamic>) {
                              // If it's a map (new messages), parse it correctly.
                              snippet = lastMessageValue['text'] ??
                                  'No message text.';
                              lastMessageSenderId =
                                  lastMessageValue['senderId'] ?? '';
                            } else {
                              // If it's a string (old messages) or null, use it directly.
                              snippet = lastMessageValue?.toString() ??
                                  'No messages yet.';
                              // Use the old senderId field as a fallback.
                              lastMessageSenderId =
                                  data['lastMessageSenderId'] ?? '';
                            }

                            if (lastMessageSenderId == _currentUserId) {
                              snippet = 'You: $snippet';
                            }
                            if (snippet.length > 35) {
                              snippet = '${snippet.substring(0, 35)}...';
                            }

                            final timestamp =
                                data['lastUpdatedAt'] as Timestamp?;
                            final timeStr = timestamp != null
                                ? DateFormat.jm().format(timestamp.toDate())
                                : '';

                            final usersWithUnread = List<String>.from(
                                data['usersWithUnread'] ?? []);
                            final isUnread =
                                usersWithUnread.contains(_currentUserId);

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    (photoUrl != null && photoUrl.isNotEmpty)
                                        ? NetworkImage(photoUrl)
                                        : null,
                                child: (photoUrl == null || photoUrl.isEmpty)
                                    ? const Icon(Icons.person_outline)
                                    : null,
                              ),
                              title: Text(otherUserName,
                                  style: TextStyle(
                                      fontWeight: isUnread
                                          ? FontWeight.bold
                                          : FontWeight.normal)),
                              subtitle: Text(snippet,
                                  style: TextStyle(
                                      fontWeight: isUnread
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isUnread
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Colors.grey)),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(timeStr),
                                  if (isUnread) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                            color: Colors.blue,
                                            shape: BoxShape.circle)),
                                  ]
                                ],
                              ),
                              onTap: () {
                                if (!mounted || otherUser == null) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MessageThreadScreen(
                                      threadId: threadId,
                                      initialAuthToken: widget.initialAuthToken,
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
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
