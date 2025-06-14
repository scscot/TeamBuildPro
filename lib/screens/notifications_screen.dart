import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // Needed for FirebaseAuth to get current user UID
import 'package:intl/intl.dart';
import '../services/session_manager.dart'; // Needed for SessionManager
import '../widgets/header_widgets.dart'; // AppHeaderWithMenu

class NotificationsScreen extends StatefulWidget {
  // Add required parameters for consistency with current app navigation
  // final Map<String, dynamic> firebaseConfig;
  final String? initialAuthToken;
  final String appId;

  const NotificationsScreen({
    super.key,
    // required this.firebaseConfig,
    this.initialAuthToken,
    required this.appId,
  });

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
    // Corrected SessionManager access: use SessionManager()
    final user = await SessionManager().getCurrentUser();
    if (!mounted) return; // Guard against setState after async gap

    if (user != null) {
      setState(() {
        _uid = user.uid;
        _notificationsFuture = _fetchNotifications(user.uid);
      });
    } else {
      // Handle case where user is not logged in, e.g., show error or redirect
      setState(() {
        _uid = null; // Ensure _uid is null
        _notificationsFuture = Future.value([]); // Provide an empty list
        // Optionally show a message to the user that they need to log in
      });
    }
  }

  Future<List<QueryDocumentSnapshot>> _fetchNotifications(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('createdAt',
              descending:
                  true) // Changed to 'createdAt' as per typical notification field
          .get();
      return snapshot.docs;
    } catch (e) {
      debugPrint('Error fetching notifications for UID $uid: $e');
      // Return empty list on error
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null || _notificationsFuture == null) {
      return Scaffold(
        appBar: AppHeaderWithMenu(
          // Pass required args
          // firebaseConfig: widget.firebaseConfig,
          initialAuthToken: widget.initialAuthToken,
          appId: widget.appId,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppHeaderWithMenu(
        // Pass required args
        // firebaseConfig: widget.firebaseConfig,
        initialAuthToken: widget.initialAuthToken,
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
                if (snapshot.hasError) {
                  debugPrint(
                      'FutureBuilder Error loading notifications: ${snapshot.error}');
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
                    // Use 'createdAt' as the timestamp field as per common notification structure
                    // and your UserModel's createdAt field.
                    final timestamp =
                        (data['createdAt'] as Timestamp?)?.toDate().toLocal();
                    final String formattedTime = timestamp != null
                        ? DateFormat.yMMMMd()
                            .add_jm()
                            .format(timestamp) // Format both date and time
                        : 'N/A';

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
                          data['title'] ??
                              'No Title', // Provide default for missing title
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
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
                                    'No message content.', // Prioritize 'body' or 'message'
                                style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 6),
                            Text(
                              formattedTime, // Display formatted time
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon:
                              const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () async {
                            // Guarded context usage
                            if (!mounted) return;
                            if (_uid == null) {
                              debugPrint(
                                  'Cannot delete notification: User UID is null.');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Cannot delete notification: User not identified.')),
                              );
                              return;
                            }
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(_uid)
                                .collection('notifications')
                                .doc(doc.id)
                                .delete();
                            // Re-fetch notifications after deletion to update UI
                            if (mounted) {
                              setState(() {
                                _notificationsFuture =
                                    _fetchNotifications(_uid!);
                              });
                            }
                          },
                        ),
                        onTap: () async {
                          // Guarded context usage
                          if (!mounted) return;
                          if (_uid == null) {
                            debugPrint(
                                'Cannot mark notification read: User UID is null.');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Cannot read notification: User not identified.')),
                            );
                            return;
                          }
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(_uid)
                              .collection('notifications')
                              .doc(doc.id)
                              .update({'read': true});
                          if (!mounted) return;
                          showDialog(
                            // ignore: use_build_context_synchronously
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text(data['title'] ?? 'Notification'),
                              content: Text(data['body'] ??
                                  data['message'] ??
                                  'No message content.'),
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
