import 'package:flutter/material.dart';
import '../services/iap_service.dart';

class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  bool isPurchasing = false;

  Future<void> _handleUpgrade() async {
    setState(() => isPurchasing = true);
    IAPService().purchaseMonthlyUpgrade(
      onSuccess: () {
        if (!mounted) return;
        setState(() => isPurchasing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Upgrade successful!')),
        );
        Navigator.pop(context);
      },
      onFailure: () {
        if (!mounted) return;
        setState(() => isPurchasing = false);
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Upgrade Failed'),
            content: const Text('Something went wrong. Please try again.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Upgrade to Pro'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Upgrade for just \$4.99/month to:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
                '• Submit your unique Business Opportunity referral link'),
            const Text('• Unlock messaging to users across your downline'),
            const Text(
                '• Ensure downline members join under YOU in the business opp'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isPurchasing ? null : _handleUpgrade,
                child: isPurchasing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Upgrade Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
