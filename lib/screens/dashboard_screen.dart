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

    _unreadMessagesSubscription = FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: userId)
        .where('isRead.$userId', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _hasUnreadMessages = snapshot.docs.isNotEmpty;
        });
      }
    });

    _unreadNotificationsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _unreadNotificationCount = snapshot.docs.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _unreadMessagesSubscription?.cancel();
    _unreadNotificationsSubscription?.cancel();
    super.dispose();
  }

  Widget buildButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool hasBadge = false,
    int badgeCount = 0,
  }) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 40, color: Colors.indigo),
                      const SizedBox(height: 12),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (hasBadge)
                  Positioned(
                    top: -10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 22, minHeight: 22),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                if (!hasBadge && _hasUnreadMessages && label == 'Messages')
                  Positioned(
                    top: -4,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppHeaderWithMenu(appId: widget.appId),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Welcome, ${user.firstName}!',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              Row(
                children: [
                  buildButton(
                    icon: Icons.person_search,
                    label: 'My Downline',
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                DownlineTeamScreen(appId: widget.appId))),
                  ),
                  const SizedBox(width: 16),
                  buildButton(
                    icon: Icons.share,
                    label: 'Grow My Team',
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ShareScreen(appId: widget.appId))),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  buildButton(
                    icon: Icons.message,
                    label: 'Messages',
                    hasBadge: _hasUnreadMessages,
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                MessageCenterScreen(appId: widget.appId))),
                  ),
                  const SizedBox(width: 16),
                  buildButton(
                    icon: Icons.notifications,
                    label: 'Notifications',
                    hasBadge: _unreadNotificationCount > 0,
                    badgeCount: _unreadNotificationCount,
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                NotificationsScreen(appId: widget.appId))),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  buildButton(
                    icon: Icons.person,
                    label: 'My Profile',
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ProfileScreen(appId: widget.appId))),
                  ),
                  const SizedBox(width: 16),
                  if (user.role == 'admin')
                    buildButton(
                      icon: Icons.settings,
                      label: 'Opportunity Settings',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          // MODIFIED: Added missing 'appId' parameter
                          builder: (_) => SettingsScreen(appId: widget.appId),
                        ),
                      ),
                    ),
                  if (user.role == 'user')
                    (user.directSponsorCount >=
                                AppConstants.projectWideDirectSponsorMin &&
                            user.totalTeamCount >=
                                AppConstants.projectWideTotalTeamMin)
                        ? buildButton(
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
                                        builder: (_) => JoinOpportunityScreen(
                                            appId: widget.appId)));
                              }
                            },
                          )
                        : Expanded(child: Container()), // Empty placeholder
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
