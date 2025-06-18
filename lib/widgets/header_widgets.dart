import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../config/app_constants.dart';
import '../screens/dashboard_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/downline_team_screen.dart';
import '../screens/share_screen.dart';
import '../screens/message_center_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/join_opportunity_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/login_screen.dart';

class AppHeaderWithMenu extends StatelessWidget implements PreferredSizeWidget {
  final String appId;

  const AppHeaderWithMenu({super.key, required this.appId});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  bool _shouldShowJoinOpportunity(UserModel? user) {
    if (user == null || user.role == 'admin' || user.bizVisitDate != null) {
      return false;
    }
    return (user.directSponsorCount) >=
            AppConstants.projectWideDirectSponsorMin &&
        (user.totalTeamCount) >= AppConstants.projectWideTotalTeamMin;
  }

  bool _shouldShowBackButton(BuildContext context) {
    return Navigator.of(context).canPop();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);

    return AppBar(
      automaticallyImplyLeading: false,
      leading: _shouldShowBackButton(context)
          ? const BackButton()
          : const SizedBox(),
      title: GestureDetector(
        onTap: () => Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => DashboardScreen(appId: appId))),
        child: const Text('TeamBuild Pro', style: TextStyle(fontSize: 18)),
      ),
      centerTitle: true,
      actions: [
        if (user != null)
          PopupMenuButton<String>(
            onSelected: (value) async {
              final navigator = Navigator.of(context);
              switch (value) {
                case 'logout':
                  await FirebaseAuth.instance.signOut();
                  navigator.pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => LoginScreen(appId: appId)),
                      (route) => false);
                  break;
                case 'join':
                  navigator.push(MaterialPageRoute(
                      builder: (_) => JoinOpportunityScreen(appId: appId)));
                  break;
                case 'downline':
                  navigator.push(MaterialPageRoute(
                      builder: (_) => DownlineTeamScreen(appId: appId)));
                  break;
                case 'share':
                  navigator.push(MaterialPageRoute(
                      builder: (_) => ShareScreen(appId: appId)));
                  break;
                case 'messages':
                  navigator.push(MaterialPageRoute(
                      builder: (_) => MessageCenterScreen(appId: appId)));
                  break;
                case 'notifications':
                  navigator.push(MaterialPageRoute(
                      builder: (_) => NotificationsScreen(appId: appId)));
                  break;
                case 'profile':
                  navigator.push(MaterialPageRoute(
                      builder: (_) => ProfileScreen(appId: appId)));
                  break;
                case 'settings':
                  navigator.push(MaterialPageRoute(
                      builder: (_) => SettingsScreen(appId: appId)));
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              if (_shouldShowJoinOpportunity(user))
                const PopupMenuItem<String>(
                    value: 'join', child: Text('Join Now!')),
              const PopupMenuItem<String>(
                  value: 'downline', child: Text('My Downline')),
              const PopupMenuItem<String>(
                  value: 'share', child: Text('Grow My Team')),
              const PopupMenuItem<String>(
                  value: 'messages', child: Text('Messages Center')),
              const PopupMenuItem<String>(
                  value: 'notifications', child: Text('Notifications')),
              const PopupMenuItem<String>(
                  value: 'profile', child: Text('My Profile')),
              if (user.role == 'admin')
                const PopupMenuItem<String>(
                    value: 'settings', child: Text('Opportunity Settings')),
              const PopupMenuItem<String>(
                  value: 'logout', child: Text('Logout')),
            ],
          )
      ],
    );
  }
}
