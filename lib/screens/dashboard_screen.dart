import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/downline_team_screen.dart'; // No longer hide UserModel here
import '../screens/profile_screen.dart';
import '../screens/share_screen.dart';
import '../services/session_manager.dart';
import '../models/user_model.dart'; // Canonical UserModel
import '../widgets/header_widgets.dart';
import '../screens/settings_screen.dart';
import '../screens/join_opportunity_screen.dart';
import '../screens/my_biz_screen.dart';
import '../screens/message_center_screen.dart';
import '../screens/notifications_screen.dart';
// import '../main.dart' as main_app; // Access global firebaseConfig

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
      if (mounted) setState(() => _isLoading = false); // Guarded setState
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

      // Fetch admin settings using the adminUid if it exists
      DocumentSnapshot<Map<String, dynamic>>? adminSettingsDoc;
      if (adminUid != null && adminUid.isNotEmpty) {
        adminSettingsDoc = await FirebaseFirestore.instance
            .collection('admin_settings')
            .doc(adminUid)
            .get();
      }

      final int directSponsorMin = adminSettingsDoc?.data()?['direct_sponsor_min'] ?? 5;
      final int totalTeamMin = adminSettingsDoc?.data()?['total_team_min'] ?? 20;

      debugPrint('📊 directSponsorMin from Firestore: $directSponsorMin');
      debugPrint('📊 totalTeamMin from Firestore: $totalTeamMin');

      if (mounted) { // Guarded setState
        setState(() {
          _user = updatedUser;
          _directSponsorMin = directSponsorMin;
          _totalTeamMin = totalTeamMin;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('🔥 Error loading dashboard data: $e');
      if (mounted) setState(() => _isLoading = false); // Guarded setState
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
      if (mounted) setState(() => _unreadNotificationCount = snapshot.docs.length); // Guarded setState
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
      appBar: AppHeaderWithMenu( // Corrected: Pass required arguments
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
            if (user?.role == 'admin')
              buildButton(
                icon: Icons.settings,
                label: 'Account Settings',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SettingsScreen( // Pass required args
                    firebaseConfig: widget.firebaseConfig,
                    initialAuthToken: widget.initialAuthToken,
                    appId: widget.appId,
                  )),
                ),
              ),
            buildButton(
              icon: Icons.person,
              label: 'My Profile',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileScreen( // Pass required args
                  firebaseConfig: widget.firebaseConfig,
                  initialAuthToken: widget.initialAuthToken,
                  appId: widget.appId,
                )),
              ),
            ),
            buildButton(
              icon: Icons.group,
              label: 'My Downline',
              onPressed: () async {
                final String? currentAuthToken = await FirebaseAuth.instance.currentUser?.getIdToken();
                if (!mounted) return; // Guarded use of context
                Navigator.push(
                  // ignore: use_build_context_synchronously
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        DownlineTeamScreen(
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
                MaterialPageRoute(builder: (_) => ShareScreen( // Pass required args
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
                    builder: (context) => MessageCenterScreen( // Pass required args
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
                    builder: (context) => NotificationsScreen( // Pass required args
                      firebaseConfig: widget.firebaseConfig,
                      initialAuthToken: widget.initialAuthToken,
                      appId: widget.appId,
                    ),
                  ),
                );
              },
            ),
            if (user?.role == 'user' &&
                (user?.directSponsorCount ?? 0) >= (_directSponsorMin ?? 5) && // Corrected field name
                (user?.totalTeamCount ?? 0) >= (_totalTeamMin ?? 20)) // Corrected field name
              buildButton(
                icon: Icons.monetization_on,
                label: user?.bizOppRefUrl != null
                    ? 'My Opportunity'
                    : 'Join Opportunity',
                onPressed: () {
                  if (user?.bizOppRefUrl != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => MyBizScreen( // Pass required args
                        firebaseConfig: widget.firebaseConfig,
                        initialAuthToken: widget.initialAuthToken,
                        appId: widget.appId,
                      )),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => JoinOpportunityScreen( // Pass required args
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
