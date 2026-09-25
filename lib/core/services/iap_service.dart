import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/iap_constants.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/payment_provider.dart';

// Provider for the IAP Service
final iapServiceProvider = Provider<IapService>((ref) {
  final service = IapService(ref);
  service.initialize();
  return service;
});

class IapService {
  final Ref _ref;
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  List<ProductDetails> _products = [];

  IapService(this._ref);

  void initialize() {
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      debugPrint('IAP Stream error: $error');
    });

    // Proactively query and cache available products
    _loadProducts();
  }

  void dispose() {
    _subscription.cancel();
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('Purchase pending: ${purchaseDetails.productID}');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          
          final success = await _verifyAndDeliverProduct(purchaseDetails);
          
          if (success) {
            if (purchaseDetails.pendingCompletePurchase) {
              await _iap.completePurchase(purchaseDetails);
            }
          }
        }
      }
    }
  }

  Future<bool> _verifyAndDeliverProduct(PurchaseDetails purchaseDetails) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return false;

    try {
      final productId = purchaseDetails.productID;

      // PRO Membership (Lifetime non-consumable)
      if (productId == IapConstants.lifetime) {
        final paymentRepo = _ref.read(paymentRepositoryProvider);
        final result = await paymentRepo.updateSubscription(
          userId: user.uid, 
          isSubscribed: true,
        );
        return await result.fold(
          (failure) async => false,
          (_) async {
            // Refresh auth state to reflect PRO status globally
            await _ref.read(authProvider.notifier).refreshUser();
            return true;
          }
        );
      }
    } catch (e) {
      debugPrint('Error delivering product: $e');
      return false;
    }
    
    return false;
  }

  Future<void> buyProduct(String productId) async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      debugPrint('Google Play Store is not available on this device.');
      throw Exception('Google Play Store is not available on this device.');
    }

    if (_products.isEmpty) {
      await _loadProducts();
    }

    try {
      final product = _products.firstWhere(
        (p) => p.id == productId,
      );

      final purchaseParam = PurchaseParam(productDetails: product);
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('Product "$productId" not found in store response. Cached products: ${_products.map((p) => p.id).toList()}');
      throw Exception(
        'Product "$productId" is not available yet. Please ensure this product ID is Active in Google Play Console and your tester account is enabled in License Testing.',
      );
    }
  }

  /// Restores previous purchases
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  Future<void> _loadProducts() async {
    final bool available = await _iap.isAvailable();
    if (!available) return;

    final ProductDetailsResponse response =
        await _iap.queryProductDetails(IapConstants.allIds.toSet());
    
    if (response.error == null) {
      _products = response.productDetails;
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('[IAP] Warning: Product IDs not found by Google Play: ${response.notFoundIDs}');
      }
    } else {
      debugPrint('[IAP] Error loading products: ${response.error}');
    }
  }
}
