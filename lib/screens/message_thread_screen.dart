// FINAL PATCHED — MessageThreadScreen with thread auto-init, anti-flicker, and restored layout

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/session_manager.dart';
import '../widgets/header_widgets.dart';

class MessageThreadScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;

  const MessageThreadScreen({
    super.key,
    required this.recipientId,
    required this.recipientName,
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

  @override
  void initState() {
    super.initState();
    _initializeThread();
  }

  Future<void> _initializeThread() async {
    final currentUser = await _sessionManager.getCurrentUser();
    if (!mounted || currentUser == null) return;

    final uid = currentUser.uid;
    final threadId = _generateThreadId(uid, widget.recipientId);
    final threadDoc =
        FirebaseFirestore.instance.collection('messages').doc(threadId);

    final docSnapshot = await threadDoc.get();
    if (!docSnapshot.exists) {
      await threadDoc.set({
        'allowedUsers': [uid, widget.recipientId],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    final recipient = await _firestoreService.getUser(widget.recipientId);

    if (!mounted) return;
    setState(() {
      _currentUserId = uid;
      _threadId = threadId;
      _recipientUser = recipient;
      _isThreadReady = true;
    });
  }

  String _generateThreadId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<QuerySnapshot> _getMessagesOnce() {
    return FirebaseFirestore.instance
        .collection('messages')
        .doc(_threadId)
        .collection('chat')
        .orderBy('timestamp', descending: false)
        .get();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _currentUserId == null || _threadId == null) return;

    await _firestoreService.sendMessage(
      senderId: _currentUserId!,
      recipientId: widget.recipientId,
      text: text,
    );
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isThreadReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final displayName = _recipientUser != null
        ? '${_recipientUser!.firstName} ${_recipientUser!.lastName}'
        : widget.recipientName;

    return Scaffold(
      appBar: AppHeaderWithMenu(),
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
            child: FutureBuilder<QuerySnapshot>(
              future: _getMessagesOnce(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
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
