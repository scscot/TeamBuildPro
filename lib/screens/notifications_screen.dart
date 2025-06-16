import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/header_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  final String? initialAuthToken;
  final String appId;

  const NotificationsScreen({
    super.key,
    this.initialAuthToken,
    required this.appId,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Future<List<QueryDocumentSnapshot>>? _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) {
      setState(() {
        _notificationsFuture = _fetchNotifications(authUser.uid);
      });
    } else {
      setState(() {
        _notificationsFuture = Future.value([]);
      });
    }
  }

  Future<List<QueryDocumentSnapshot>> _fetchNotifications(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs;
    } catch (e) {
      debugPrint('Error fetching notifications for UID $uid: $e');
      return [];
    }
  }

  Future<void> _deleteNotification(String docId) async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(authUser.uid)
          .collection('notifications')
          .doc(docId)
          .delete();
      if (mounted) {
        setState(() {
          _notificationsFuture = _fetchNotifications(authUser.uid);
        });
      }
    } catch (e) {
      debugPrint("Error deleting notification: $e");
    }
  }

  Future<void> _markNotificationAsRead(DocumentSnapshot doc) async {
    try {
      await doc.reference.update({'read': true});
      if (!mounted) return;
      final data = doc.data() as Map<String, dynamic>;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(data['title'] ?? 'Notification'),
          content:
              Text(data['body'] ?? data['message'] ?? 'No message content.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint("Error marking notification as read: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeaderWithMenu(
        appId: widget.appId,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 24.0),
            child: Center(
              child: Text(
                'Notifications',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<QueryDocumentSnapshot>>(
              future: _notificationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('Error loading notifications'));
                }
                final docs = snapshot.data ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No notifications yet.'));
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final timestamp =
                        (data['createdAt'] as Timestamp?)?.toDate().toLocal();
                    final String formattedTime = timestamp != null
                        ? DateFormat.yMMMMd().add_jm().format(timestamp)
                        : 'N/A';
                    final isRead = data['read'] == true;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        leading: Icon(
                          isRead
                              ? Icons.notifications_none
                              : Icons.notifications_active,
                          color: isRead ? Colors.grey : Colors.deepPurple,
                          size: 28,
                        ),
                        title: Text(
                          data['title'] ?? 'No Title',
                          style: TextStyle(
                            fontWeight:
                                isRead ? FontWeight.normal : FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text(
                                data['body'] ??
                                    data['message'] ??
                                    'No message content.',
                                style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 6),
                            Text(
                              formattedTime,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon:
                              const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => _deleteNotification(doc.id),
                        ),
                        onTap: () {
                          // STYLE: Added curly braces for consistency
                          if (!isRead) {
                            _markNotificationAsRead(doc);
                          } else {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(data['title'] ?? 'Notification'),
                                content: Text(data['body'] ??
                                    data['message'] ??
                                    'No message content.'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
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
