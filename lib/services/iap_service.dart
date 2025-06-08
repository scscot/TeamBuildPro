import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  final String _subscriptionId = 'teambuild_pro_monthly';

  bool available = false;
  List<ProductDetails> products = [];
  bool isPurchased = false;

  Future<void> init() async {
    available = await _iap.isAvailable();
    if (!available) {
      debugPrint('⚠️ IAP not available');
      return;
    }

    final ProductDetailsResponse response =
        await _iap.queryProductDetails({_subscriptionId});
    if (response.error != null || response.productDetails.isEmpty) {
      debugPrint('❌ Error loading products: ${response.error}');
      return;
    }
    products = response.productDetails;
    debugPrint('✅ Loaded IAP products');

    _subscription = _iap.purchaseStream.listen(_onPurchaseUpdated, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      debugPrint('❌ Purchase stream error: $error');
    });
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchases) {
    for (var purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        isPurchased = true;
        _verifyAndComplete(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('❌ Purchase error: ${purchase.error}');
      }
    }
  }

  Future<void> _verifyAndComplete(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
    debugPrint('✅ Purchase verified and completed');
  }

  Future<void> purchaseMonthlyUpgrade({
    required VoidCallback onSuccess,
    required VoidCallback onFailure,
    VoidCallback? onComplete,
  }) async {
    try {
      final product = products.firstWhere((p) => p.id == _subscriptionId);
      final purchaseParam = PurchaseParam(productDetails: product);
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);

      // If successful, update Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'messaging_unlocked': true,
        });
        onSuccess();
      } else {
        onFailure();
      }
    } catch (e) {
      debugPrint('❌ Error purchasing upgrade: $e');
      onFailure();
    } finally {
      onComplete?.call();
    }
  }

  void dispose() {
    _subscription.cancel();
  }
}
