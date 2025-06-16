// lib/widgets/header_widgets.dart
// ignore_for_file: use_build_context_synchronously

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
    final user = Provider.of<UserModel?>(context, listen: false);

    return AppBar(
      backgroundColor: const Color(0xFFEDE7F6),
      automaticallyImplyLeading: false,
      leading: _shouldShowBackButton(context)
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context))
          : null,
      title: GestureDetector(
        onTap: () {
          final currentRoute = ModalRoute.of(context);
          if (currentRoute != null && !currentRoute.isFirst) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                  builder: (_) => DashboardScreen(appId: appId),
                  settings: const RouteSettings(name: '/')),
              (route) => false,
            );
          }
        },
        child: const Text('TeamBuild Pro',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
      ),
      centerTitle: true,
      actions: [
        if (user != null) // Only show the menu if a user is logged in
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.black),
            onSelected: (String value) async {
              if (value == 'logout') {
                // --- THIS IS THE FIX ---
                // First, pop all pages off the stack until we are at the root.
                Navigator.of(context).popUntil((route) => route.isFirst);
                // Then, sign out. The StreamProvider will now correctly show the LoginScreen.
                await FirebaseAuth.instance.signOut();
                return;
              }

              final navigator = Navigator.of(context);
              switch (value) {
                case 'profile':
                  navigator.push(MaterialPageRoute(
                      builder: (_) => ProfileScreen(appId: appId)));
                  break;
                case 'downline':
                  navigator.push(MaterialPageRoute(
                      builder: (_) => DownlineTeamScreen(appId: appId)));
                  break;
                case 'share':
                  navigator.push(MaterialPageRoute(
                      builder: (_) => ShareScreen(appId: appId)));
                  break;
                case 'join':
                  navigator.push(MaterialPageRoute(
                      builder: (_) => JoinOpportunityScreen(appId: appId)));
                  break;
                case 'messages':
                  navigator.push(MaterialPageRoute(
                      builder: (_) => MessageCenterScreen(appId: appId)));
                  break;
                case 'notifications':
                  navigator.push(MaterialPageRoute(
                      builder: (_) => NotificationsScreen(appId: appId)));
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
                  value: 'profile', child: Text('My Profile')),
              const PopupMenuItem<String>(
                  value: 'downline', child: Text('My Downline')),
              const PopupMenuItem<String>(
                  value: 'share', child: Text('Grow My Team')),
              const PopupMenuItem<String>(
                  value: 'messages', child: Text('Messages Center')),
              const PopupMenuItem<String>(
                  value: 'notifications', child: Text('Notifications')),
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
