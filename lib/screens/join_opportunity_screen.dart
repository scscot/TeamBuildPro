import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'update_profile_screen.dart';
import '../models/user_model.dart';
import '../widgets/header_widgets.dart';

class JoinOpportunityScreen extends StatefulWidget {
  final String appId;

  const JoinOpportunityScreen({super.key, required this.appId});

  @override
  State<JoinOpportunityScreen> createState() => _JoinOpportunityScreenState();
}

class _JoinOpportunityScreenState extends State<JoinOpportunityScreen> {
  String? _adminMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAdminSettings();
  }

  Future<void> _fetchAdminSettings() async {
    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    // MODIFIED: Logic to find the upline admin using upline_refs
    String? adminUid;
    if (user.role == 'admin') {
      adminUid = user.uid;
    } else if (user.uplineRefs.isNotEmpty) {
      adminUid = user.uplineRefs.last;
    }

    if (adminUid != null) {
      final doc = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc(adminUid)
          .get();
      if (mounted && doc.exists) {
        setState(() {
          _adminMessage = doc.data()?['join_opp_msg'];
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeaderWithMenu(appId: widget.appId),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Congratulations!',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  const Text(
                      'You are now eligible to join our primary business opportunity.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18)),
                  if (_adminMessage != null && _adminMessage!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        _adminMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 16, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                UpdateProfileScreen(appId: widget.appId)),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    child: const Text('Proceed to Next Step'),
                  ),
                ],
              ),
            ),
    );
  }
}
