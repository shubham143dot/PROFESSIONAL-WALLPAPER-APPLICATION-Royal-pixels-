import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/iap_constants.dart';
import '../../domain/repositories/payment_repository.dart';
import '../../domain/repositories/diamond_repository.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/diamond_provider.dart';
import '../../presentation/providers/payment_provider.dart';

// Provider for the IAP Service
final iapServiceProvider = Provider<IapService>((ref) {
  final service = IapService(ref);
  service.initialize();
  return service;
});

class IapService {
  final ProviderRef _ref;
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
  }

  void dispose() {
    _subscription.cancel();
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI if needed
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

      // 1. Consumable (Diamonds)
      if (productId.startsWith('pack_')) {
        int amount = int.parse(productId.split('_')[1]);
        
        // Use DiamondNotifier to add diamonds so UI updates automatically
        final success = await _ref.read(diamondProvider.notifier).addDiamonds(user.uid, amount);
        return success;
      }
      
      // 2. Non-Consumable / Subscription (PRO Membership)
      if (productId == IapConstants.lifetime || 
          productId == IapConstants.monthly || 
          productId == IapConstants.semiAnnual || 
          productId == IapConstants.annual) {
        
        // Update subscription status in backend
        final paymentRepo = _ref.read(paymentRepositoryProvider);
        final result = await paymentRepo.updateSubscription(
          userId: user.uid, 
          isSubscribed: true,
        );
        
        return result.fold(
          (failure) => false,
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

  /// Initiates the purchase flow
  Future<void> buyProduct(String productId) async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      debugPrint('Store not available');
      return;
    }

    if (_products.isEmpty) {
      await _loadProducts();
    }

    try {
      final product = _products.firstWhere(
        (p) => p.id == productId,
      );

      final purchaseParam = PurchaseParam(productDetails: product);

      if (productId.startsWith('pack_')) {
        await _iap.buyConsumable(purchaseParam: purchaseParam);
      } else {
        await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      }
    } catch (e) {
      debugPrint('Product not found: $productId');
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
    } else {
      debugPrint('Error loading products: ${response.error}');
    }
  }
}
