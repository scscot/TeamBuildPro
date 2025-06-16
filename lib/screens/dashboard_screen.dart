import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/user_model.dart';
import '../widgets/header_widgets.dart';
import '../screens/settings_screen.dart';
import '../screens/join_opportunity_screen.dart';
import '../screens/my_biz_screen.dart';
import '../screens/message_center_screen.dart';
import '../screens/notifications_screen.dart';
import '../config/app_constants.dart';
import '../screens/downline_team_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/share_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String appId;

  const DashboardScreen({
    super.key,
    required this.appId,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StreamSubscription? _unreadMessagesSubscription;
  StreamSubscription? _unreadNotificationsSubscription;
  int _unreadNotificationCount = 0;
  bool _hasUnreadMessages = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<UserModel?>(context);
    if (user != null) {
      _setupListeners(user.uid);
    }
  }

  void _setupListeners(String userId) {
    _unreadMessagesSubscription?.cancel();
    _unreadNotificationsSubscription?.cancel();

    // --- THIS IS THE FIX ---
    // This query is now valid as it only uses one 'array-contains' filter.
    // It directly checks if there are any message threads marked as unread for the current user.
    final messageQuery = FirebaseFirestore.instance
        .collection('messages')
        .where('usersWithUnread', arrayContains: userId)
        .limit(1);

    _unreadMessagesSubscription = messageQuery.snapshots().listen((snapshot) {
      if (mounted) {
        setState(() => _hasUnreadMessages = snapshot.docs.isNotEmpty);
      }
    }, onError: (error) {
      debugPrint("Error listening for unread messages: $error");
    });

    final notificationQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false);

    _unreadNotificationsSubscription =
        notificationQuery.snapshots().listen((snapshot) {
      if (mounted) {
        setState(() => _unreadNotificationCount = snapshot.docs.length);
      }
    }, onError: (error) {
      debugPrint("Error in notification snapshot listener: $error");
    });
  }

  @override
  void dispose() {
    _unreadMessagesSubscription?.cancel();
    _unreadNotificationsSubscription?.cancel();
    super.dispose();
  }

  Widget buildButton(
      {required IconData icon,
      required String label,
      required VoidCallback onPressed,
      bool showRedDot = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: 22),
            if (showRedDot)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle)),
              ),
          ],
        ),
        label: Text(label, style: const TextStyle(fontSize: 16)),
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppHeaderWithMenu(appId: widget.appId),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 24.0),
                child: Center(
                    child: Text('Dashboard',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(height: 32),
              buildButton(
                  icon: Icons.group,
                  label: 'My Downline',
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              DownlineTeamScreen(appId: widget.appId)))),
              buildButton(
                  icon: Icons.trending_up_rounded,
                  label: 'Grow My Team',
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ShareScreen(appId: widget.appId)))),
              buildButton(
                  icon: Icons.message,
                  label: 'Message Center',
                  showRedDot: _hasUnreadMessages,
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              MessageCenterScreen(appId: widget.appId)))),
              buildButton(
                  icon: Icons.notifications,
                  label: 'Notifications',
                  showRedDot: _unreadNotificationCount > 0,
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              NotificationsScreen(appId: widget.appId)))),
              buildButton(
                  icon: Icons.person,
                  label: 'My Profile',
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ProfileScreen(appId: widget.appId)))),
              if (user.role == 'admin')
                buildButton(
                    icon: Icons.settings,
                    label: 'Opportunity Settings',
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                SettingsScreen(appId: widget.appId)))),
              if (user.role == 'user' &&
                  (user.directSponsorCount) >=
                      AppConstants.projectWideDirectSponsorMin &&
                  (user.totalTeamCount) >= AppConstants.projectWideTotalTeamMin)
                buildButton(
                  icon: Icons.monetization_on,
                  label: user.bizOppRefUrl != null
                      ? 'My Opportunity'
                      : 'Join Opportunity',
                  onPressed: () {
                    if (user.bizOppRefUrl != null) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  MyBizScreen(appId: widget.appId)));
                    } else {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  JoinOpportunityScreen(appId: widget.appId)));
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
