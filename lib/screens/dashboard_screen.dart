import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/downline_team_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/share_screen.dart';
import '../services/session_manager.dart';
import '../models/user_model.dart';
import '../widgets/header_widgets.dart';
import '../screens/settings_screen.dart';
import '../screens/join_opportunity_screen.dart';
import '../screens/my_biz_screen.dart';
import '../screens/message_center_screen.dart';
import '../screens/notifications_screen.dart';
import '../config/app_constants.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> firebaseConfig;
  final String? initialAuthToken;
  final String appId;

  const DashboardScreen({
    super.key,
    required this.firebaseConfig,
    this.initialAuthToken,
    required this.appId,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  UserModel? _user;
  bool _isLoading = true;
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserAndSettings();
    _fetchUnreadNotificationCount();
  }

  Future<void> _loadUserAndSettings() async {
    final sessionUser = await SessionManager().getCurrentUser();

    if (sessionUser == null || sessionUser.uid.isEmpty) {
      debugPrint('❌ Session user is null or has empty UID');
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(sessionUser.uid)
          .get();

      final updatedUser = UserModel.fromFirestore(userDoc);

      if (mounted) {
        setState(() {
          _user = updatedUser;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('🔥 Error loading dashboard data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchUnreadNotificationCount() async {
    final user = await SessionManager().getCurrentUser();
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      // FIXED: Added curly braces to satisfy the linting rule.
      if (mounted) {
        setState(() => _unreadNotificationCount = snapshot.docs.length);
      }
    });
  }

  Widget buildButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool showRedDot = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = _user;

    return Scaffold(
      appBar: AppHeaderWithMenu(
        firebaseConfig: widget.firebaseConfig,
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
                child: Text(
                  'Dashboard',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 32),
            buildButton(
              icon: Icons.group,
              label: 'My Downline',
              onPressed: () async {
                final String? currentAuthToken =
                    await FirebaseAuth.instance.currentUser?.getIdToken();
                if (!mounted) return;
                Navigator.push(
                  // ignore: use_build_context_synchronously
                  context,
                  MaterialPageRoute(
                    builder: (_) => DownlineTeamScreen(
                      firebaseConfig: widget.firebaseConfig,
                      initialAuthToken: currentAuthToken ?? '',
                      appId: widget.appId,
                    ),
                  ),
                );
              },
            ),
            buildButton(
              icon: Icons.trending_up_rounded,
              label: 'Grow My Team',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ShareScreen(
                          firebaseConfig: widget.firebaseConfig,
                          initialAuthToken: widget.initialAuthToken,
                          appId: widget.appId,
                        )),
              ),
            ),
            buildButton(
              icon: Icons.message,
              label: 'Message Center',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MessageCenterScreen(
                      firebaseConfig: widget.firebaseConfig,
                      initialAuthToken: widget.initialAuthToken,
                      appId: widget.appId,
                    ),
                  ),
                );
              },
            ),
            buildButton(
              icon: Icons.notifications,
              label: 'Notifications',
              showRedDot: _unreadNotificationCount > 0,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NotificationsScreen(
                      firebaseConfig: widget.firebaseConfig,
                      initialAuthToken: widget.initialAuthToken,
                      appId: widget.appId,
                    ),
                  ),
                );
              },
            ),
            buildButton(
              icon: Icons.person,
              label: 'My Profile',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                          firebaseConfig: widget.firebaseConfig,
                          initialAuthToken: widget.initialAuthToken,
                          appId: widget.appId,
                        )),
              ),
            ),
            if (user?.role == 'admin')
              buildButton(
                icon: Icons.settings,
                label: 'Opportunity Settings',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SettingsScreen(
                            firebaseConfig: widget.firebaseConfig,
                            initialAuthToken: widget.initialAuthToken,
                            appId: widget.appId,
                          )),
                ),
              ),
            if (user?.role == 'user' &&
                (user?.directSponsorCount ?? 0) >=
                    AppConstants.projectWideDirectSponsorMin &&
                (user?.totalTeamCount ?? 0) >=
                    AppConstants.projectWideTotalTeamMin)
              buildButton(
                icon: Icons.monetization_on,
                label: user?.bizOppRefUrl != null
                    ? 'My Opportunity'
                    : 'Join Opportunity',
                onPressed: () {
                  if (user?.bizOppRefUrl != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => MyBizScreen(
                                firebaseConfig: widget.firebaseConfig,
                                initialAuthToken: widget.initialAuthToken,
                                appId: widget.appId,
                              )),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => JoinOpportunityScreen(
                                firebaseConfig: widget.firebaseConfig,
                                initialAuthToken: widget.initialAuthToken,
                                appId: widget.appId,
                              )),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
