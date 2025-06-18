import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/header_widgets.dart';
import '../services/firestore_service.dart';
import 'message_thread_screen.dart';
import '../models/user_model.dart';

class MessageCenterScreen extends StatefulWidget {
  final String appId;

  const MessageCenterScreen({
    super.key,
    required this.appId,
  });

  @override
  State<MessageCenterScreen> createState() => _MessageCenterScreenState();
}

class _MessageCenterScreenState extends State<MessageCenterScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String? _currentUserId;
  Stream<QuerySnapshot>? _threadsStream;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
        _threadsStream = FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: _currentUserId)
            .orderBy('lastMessageTimestamp', descending: true)
            .snapshots();
      });
    }
  }

  Future<UserModel?> _getOtherUser(List<dynamic> participants) async {
    final otherUserId = participants.firstWhere((id) => id != _currentUserId,
        orElse: () => null);
    if (otherUserId != null) {
      return await _firestoreService.getUser(otherUserId);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeaderWithMenu(appId: widget.appId),
      body: _currentUserId == null
          ? const Center(child: Text('Please log in to see messages.'))
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Messages',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _threadsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                            child: Text('No message threads found.'));
                      }
                      final threads = snapshot.data!.docs;
                      return ListView.builder(
                        itemCount: threads.length,
                        itemBuilder: (context, index) {
                          final thread = threads[index];
                          final data = thread.data() as Map<String, dynamic>;
                          final participants =
                              List<String>.from(data['participants'] ?? []);
                          final lastMessage =
                              data['lastMessage'] ?? 'No message yet.';
                          final timestamp =
                              data['lastMessageTimestamp'] as Timestamp?;

                          return FutureBuilder<UserModel?>(
                            future: _getOtherUser(participants),
                            builder: (context, userSnapshot) {
                              if (!userSnapshot.hasData) {
                                return const ListTile(
                                    title: Text('Loading chat...'));
                              }
                              final otherUser = userSnapshot.data;
                              final otherUserName = otherUser != null
                                  ? '${otherUser.firstName} ${otherUser.lastName}'
                                  : 'Unknown User';

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: otherUser?.photoUrl != null
                                      ? NetworkImage(otherUser!.photoUrl!)
                                      : null,
                                  child: otherUser?.photoUrl == null
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(otherUserName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                trailing: timestamp != null
                                    ? Text(
                                        DateFormat.yMMMd()
                                            .add_jm()
                                            .format(timestamp.toDate()),
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey))
                                    : null,
                                onTap: () {
                                  if (otherUser != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MessageThreadScreen(
                                          threadId: thread.id,
                                          appId: widget.appId,
                                          recipientId: otherUser.uid,
                                          recipientName: otherUserName,
                                        ),
                                      ),
                                    );
                                  }
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
    );
  }
}
