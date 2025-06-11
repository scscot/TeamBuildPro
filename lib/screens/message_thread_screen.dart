// FINAL PATCHED — MessageThreadScreen with thread auto-init, anti-flicker, and restored layout

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // Added for StreamSubscription

import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/session_manager.dart';
import '../widgets/header_widgets.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // Needed for FirebaseAuth to get currentUser Uid

class MessageThreadScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  // Add required parameters for consistency with current app navigation
  final Map<String, dynamic> firebaseConfig;
  final String? initialAuthToken;
  final String appId;
  final String? threadId; // Optional if coming from a direct thread link

  const MessageThreadScreen({
    super.key,
    required this.recipientId,
    required this.recipientName,
    required this.firebaseConfig, // Required
    this.initialAuthToken,       // Nullable
    required this.appId,         // Required
    this.threadId,               // Optional
  });

  @override
  State<MessageThreadScreen> createState() => _MessageThreadScreenState();
}

class _MessageThreadScreenState extends State<MessageThreadScreen> {
  final TextEditingController _controller = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final SessionManager _sessionManager = SessionManager();

  String? _currentUserId;
  UserModel? _recipientUser; // Holds the UserModel of the recipient
  String? _threadId;
  bool _isThreadReady = false;

  // StreamSubscription for real-time messages
  StreamSubscription<QuerySnapshot>? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _initializeThread();
  }

  Future<void> _initializeThread() async {
    final currentUser = await _sessionManager.getCurrentUser();
    if (!mounted || currentUser == null) {
      debugPrint('Error: Current user not found for message thread.');
      return;
    }

    final uid = currentUser.uid;

    // Use widget.threadId if provided, otherwise generate a new one
    final calculatedThreadId = widget.threadId ?? _generateThreadId(uid, widget.recipientId);
    final threadDocRef = FirebaseFirestore.instance.collection('messages').doc(calculatedThreadId);

    final docSnapshot = await threadDocRef.get();
    if (!docSnapshot.exists) {
      await threadDocRef.set({
        'allowedUsers': [uid, widget.recipientId],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // Fetch the recipient's UserModel for their photo and full name
    final recipient = await _firestoreService.getUser(widget.recipientId);

    if (!mounted) return; // Guard against setState after async gap

    setState(() {
      _currentUserId = uid;
      _threadId = calculatedThreadId;
      _recipientUser = recipient; // Assign the fetched UserModel here
      _isThreadReady = true;
    });

    // Note: _listenForMessages is typically called here if you want a local StreamBuilder
    // to listen to it. For now, the StreamBuilder in build() directly consumes the Firestore snapshots().
  }

  // This method is no longer needed with StreamBuilder directly in build.
  // Future<QuerySnapshot> _getMessagesOnce() {
  //   if (_threadId == null) {
  //     debugPrint('Cannot get messages: Thread ID is null.');
  //     // Return an empty QuerySnapshot instead of null
  //     return Future.value(FirebaseFirestore.instance.collection('dummy').get());
  //   }
  //   return FirebaseFirestore.instance
  //       .collection('messages')
  //       .doc(_threadId)
  //       .collection('chat')
  //       .orderBy('timestamp', descending: false)
  //       .get();
  // }

  String _generateThreadId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    // Corrected: Use _currentUserId and _threadId which are state variables
    if (text.isEmpty || _currentUserId == null || _threadId == null || _recipientUser == null) {
      debugPrint('Cannot send message: Text empty or IDs/Recipient null. Current User: $_currentUserId, Thread ID: $_threadId, Recipient: ${_recipientUser?.uid}');
      if (!mounted) return; // Guard context usage before SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot send empty message or user data missing.')),
      );
      return;
    }

    await _firestoreService.sendMessage(
      threadId: _threadId!, // Non-nullable after check
      senderId: _currentUserId!, // Non-nullable after check
      recipientId: widget.recipientId, // This is the ID of the person we are talking to
      text: text,
      timestamp: FieldValue.serverTimestamp(), // Firestore server timestamp
    );
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    _messagesSubscription?.cancel(); // Cancel messages subscription
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isThreadReady) {
      return Scaffold(
        appBar: AppHeaderWithMenu( // Pass required args
          firebaseConfig: widget.firebaseConfig,
          initialAuthToken: widget.initialAuthToken,
          appId: widget.appId,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Corrected: Use _recipientUser properties directly, provide fallbacks
    final displayName = _recipientUser != null
        ? '${_recipientUser!.firstName ?? ''} ${_recipientUser!.lastName ?? ''}'.trim()
        : widget.recipientName; // Fallback to widget.recipientName if _recipientUser not loaded

    return Scaffold(
      appBar: AppHeaderWithMenu( // Pass required args
        firebaseConfig: widget.firebaseConfig,
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
                  // Corrected: Use _recipientUser.photoUrl
                  backgroundImage: _recipientUser?.photoUrl != null &&
                          _recipientUser!.photoUrl!.isNotEmpty
                      ? NetworkImage(_recipientUser!.photoUrl!)
                      : const AssetImage('assets/images/default_avatar.png') // Ensure asset exists
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
            child: StreamBuilder<QuerySnapshot>( // Changed to StreamBuilder for real-time updates
              stream: _threadId != null // Only provide stream if threadId is ready
                  ? FirebaseFirestore.instance
                      .collection('messages')
                      .doc(_threadId!) // Use _threadId! as it's checked above
                      .collection('chat')
                      .orderBy('timestamp', descending: false)
                      .snapshots()
                  : null, // Provide null stream if not ready
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('Error loading messages: ${snapshot.error}');
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting || snapshot.data == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs; // snapshot.data is non-null here
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
