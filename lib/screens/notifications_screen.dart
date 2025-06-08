import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_manager.dart';
import '../widgets/header_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String? _uid;
  Future<List<QueryDocumentSnapshot>>? _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final user = await SessionManager.instance.getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _uid = user.uid;
        _notificationsFuture = _fetchNotifications(user.uid);
      });
    }
  }

  Future<List<QueryDocumentSnapshot>> _fetchNotifications(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .get();
    return snapshot.docs;
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null || _notificationsFuture == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppHeaderWithMenu(),
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
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('Error loading notifications'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
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
                        (data['timestamp'] as Timestamp).toDate().toLocal();
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
                          data['read'] == true
                              ? Icons.notifications_none
                              : Icons.notifications_active,
                          color: data['read'] == true
                              ? Colors.grey
                              : Colors.deepPurple,
                          size: 28,
                        ),
                        title: Text(
                          data['title'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text(data['message'] ?? '',
                                style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 6),
                            Text(
                              '${timestamp.toLocal()}'.split('.').first,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon:
                              const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(_uid)
                                .collection('notifications')
                                .doc(doc.id)
                                .delete();
                            setState(() {
                              _notificationsFuture = _fetchNotifications(_uid!);
                            });
                          },
                        ),
                        onTap: () async {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(_uid)
                              .collection('notifications')
                              .doc(doc.id)
                              .update({'read': true});
                          if (!context.mounted) return;
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text(data['title'] ?? 'Notification'),
                              content: Text(data['message'] ?? ''),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
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
