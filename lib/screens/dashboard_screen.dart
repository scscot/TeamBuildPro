import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  UserModel? _user;
  int? _directSponsorMin;
  int? _totalTeamMin;
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
      setState(() => _isLoading = false);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(sessionUser.uid)
          .get();

      final updatedUser = UserModel.fromFirestore(userDoc);
      final adminUid = updatedUser.uplineAdmin;
      debugPrint('🔎 uplineAdmin from Firestore: $adminUid');

      final adminSettings = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc(adminUid)
          .get();

      final int directSponsorMin =
          adminSettings.data()?['direct_sponsor_min'] ?? 5;
      final int totalTeamMin = adminSettings.data()?['total_team_min'] ?? 20;

      debugPrint('📊 directSponsorMin from Firestore: $directSponsorMin');
      debugPrint('📊 totalTeamMin from Firestore: $totalTeamMin');

      setState(() {
        _user = updatedUser;
        _directSponsorMin = directSponsorMin;
        _totalTeamMin = totalTeamMin;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('🔥 Error loading dashboard data: $e');
      setState(() => _isLoading = false);
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
      setState(() => _unreadNotificationCount = snapshot.docs.length);
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
      appBar: AppHeaderWithMenu(),
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
            if (user?.role == 'admin')
              buildButton(
                icon: Icons.settings,
                label: 'Account Settings',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            buildButton(
              icon: Icons.person,
              label: 'My Profile',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            ),
            buildButton(
              icon: Icons.group,
              label: 'My Downline',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const DownlineTeamScreen(referredBy: 'demo-user'),
                ),
              ),
            ),
            buildButton(
              icon: Icons.trending_up_rounded,
              label: 'Grow My Team',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ShareScreen()),
              ),
            ),
            buildButton(
              icon: Icons.message,
              label: 'Message Center',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MessageCenterScreen(),
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
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
              },
            ),
            if (user?.role == 'user' &&
                (user?.directSponsorCount ?? 0) >= (_directSponsorMin ?? 5) &&
                (user?.totalTeamCount ?? 0) >= (_totalTeamMin ?? 20))
              buildButton(
                icon: Icons.monetization_on,
                label: user?.bizOppRefUrl != null
                    ? 'My Opportunity'
                    : 'Join Opportunity',
                onPressed: () {
                  if (user?.bizOppRefUrl != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyBizScreen()),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const JoinOpportunityScreen()),
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
