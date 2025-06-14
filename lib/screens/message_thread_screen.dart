import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/session_manager.dart';
import '../widgets/header_widgets.dart';

class MessageThreadScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  // final Map<String, dynamic> firebaseConfig;
  final String? initialAuthToken;
  final String appId;
  final String? threadId;

  const MessageThreadScreen({
    super.key,
    required this.recipientId,
    required this.recipientName,
    // required this.firebaseConfig,
    this.initialAuthToken,
    required this.appId,
    this.threadId,
  });

  @override
  State<MessageThreadScreen> createState() => _MessageThreadScreenState();
}

class _MessageThreadScreenState extends State<MessageThreadScreen> {
  final TextEditingController _controller = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final SessionManager _sessionManager = SessionManager();

  String? _currentUserId;
  UserModel? _recipientUser;
  String? _threadId;
  bool _isThreadReady = false;

  StreamSubscription<QuerySnapshot>? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _initializeThread();
  }

  // NEW: Method to update read status
  void _markMessagesAsRead(List<QueryDocumentSnapshot> messages) {
    if (_threadId == null) return;

    // Use a write batch to update all unread messages in one server operation
    final batch = FirebaseFirestore.instance.batch();

    for (var doc in messages) {
      final data = doc.data() as Map<String, dynamic>;
      // Only mark messages as read if they were sent by the other person
      if (data['senderId'] != _currentUserId && data['read'] == false) {
        batch.update(doc.reference, {'read': true});
      }
    }

    batch.commit().catchError((error) {
      debugPrint("Failed to mark messages as read: $error");
    });
  }

  Future<void> _initializeThread() async {
    final currentUser = await _sessionManager.getCurrentUser();
    if (!mounted || currentUser == null) {
      debugPrint('Error: Current user not found for message thread.');
      return;
    }

    final uid = currentUser.uid;

    final calculatedThreadId =
        widget.threadId ?? _generateThreadId(uid, widget.recipientId);
    final threadDocRef = FirebaseFirestore.instance
        .collection('messages')
        .doc(calculatedThreadId);

    final docSnapshot = await threadDocRef.get();
    if (!docSnapshot.exists) {
      await threadDocRef.set({
        'allowedUsers': [uid, widget.recipientId],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    final recipient = await _firestoreService.getUser(widget.recipientId);

    if (!mounted) return;

    setState(() {
      _currentUserId = uid;
      _threadId = calculatedThreadId;
      _recipientUser = recipient;
      _isThreadReady = true;
    });
  }

  String _generateThreadId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty ||
        _currentUserId == null ||
        _threadId == null ||
        _recipientUser == null) {
      debugPrint(
          'Cannot send message: Text empty or IDs/Recipient null. Current User: $_currentUserId, Thread ID: $_threadId, Recipient: ${_recipientUser?.uid}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cannot send empty message or user data missing.')),
      );
      return;
    }

    await _firestoreService.sendMessage(
      threadId: _threadId!,
      senderId: _currentUserId!,
      recipientId: widget.recipientId,
      text: text,
      timestamp: FieldValue.serverTimestamp(),
    );
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    _messagesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isThreadReady) {
      return Scaffold(
        appBar: AppHeaderWithMenu(
          // firebaseConfig: widget.firebaseConfig,
          initialAuthToken: widget.initialAuthToken,
          appId: widget.appId,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final displayName = _recipientUser != null
        ? '${_recipientUser!.firstName ?? ''} ${_recipientUser!.lastName ?? ''}'
            .trim()
        : widget.recipientName;

    return Scaffold(
      appBar: AppHeaderWithMenu(
        // firebaseConfig: widget.firebaseConfig,
        initialAuthToken: widget.initialAuthToken,
        appId: widget.appId,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: _recipientUser?.photoUrl != null &&
                          _recipientUser!.photoUrl!.isNotEmpty
                      ? NetworkImage(_recipientUser!.photoUrl!)
                      : const AssetImage('assets/images/default_avatar.png')
                          as ImageProvider,
                ),
                const SizedBox(height: 8),
                Text(displayName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Divider(height: 32),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _threadId != null
                  ? FirebaseFirestore.instance
                      .collection('messages')
                      .doc(_threadId!)
                      .collection('chat')
                      .orderBy('timestamp', descending: false)
                      .snapshots()
                  : null,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('Error loading messages: ${snapshot.error}');
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting ||
                    snapshot.data == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                // MODIFIED: Mark incoming messages as read after the frame is built
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _markMessagesAsRead(docs);
                });

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == _currentUserId;
                    final timestamp = data['timestamp'] as Timestamp?;
                    final timeStr = timestamp != null
                        ? DateFormat.jm().format(timestamp.toDate())
                        : '';
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 300),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['text'] ?? '',
                              style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeStr,
                              style: TextStyle(
                                  fontSize: 10,
                                  color:
                                      isMe ? Colors.white70 : Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
