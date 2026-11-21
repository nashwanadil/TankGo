import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

const idTrip = 'tankgo_trip_1m';
const idYear = 'tankgo_yearly';
const idLife = 'tankgo_lifetime';
const productIds = {idTrip, idYear, idLife};

/// Free users see this many days of history; Premium sees everything.
const freeDays = 30;

/// Dev-only unlock for testing without Play Console (`--dart-define=PREMIUM_DEBUG=true`).
const premiumDebug = bool.fromEnvironment('PREMIUM_DEBUG');

/// Entitlement length per product; null = forever.
Duration? entitlementFor(String id) => switch (id) {
      idTrip => const Duration(days: 31),
      idYear => const Duration(days: 366),
      _ => null,
    };

/// Client-side entitlement store (no server validation) backed by Play Billing.
class Premium extends ChangeNotifier {
  Premium(this._p, {this.billing = true, DateTime Function()? now}) : _now = now ?? DateTime.now;
  final SharedPreferences _p;
  final bool billing;
  final DateTime Function() _now;

  List<ProductDetails> products = const [];
  bool storeReady = false;
  bool busy = false;
  String? error;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool get lifetime => _p.getBool('p_life') ?? false;
  DateTime? get until {
    final v = _p.getInt('p_until');
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  }

  bool get isPremium => lifetime || (until?.isAfter(_now()) ?? false);

  Future<void> grant(String id, DateTime when) async {
    final d = entitlementFor(id);
    if (d == null) {
      await _p.setBool('p_life', true);
    } else {
      final end = when.add(d);
      final cur = until;
      if (cur == null || end.isAfter(cur)) await _p.setInt('p_until', end.millisecondsSinceEpoch);
    }
    notifyListeners();
  }

  Future<void> start() async {
    if (!billing || kIsWeb) return;
    try {
      final iap = InAppPurchase.instance;
      _sub = iap.purchaseStream.listen(_onPurchases, onError: (Object e) => _fail('$e'));
      storeReady = await iap.isAvailable();
      if (storeReady) {
        final r = await iap.queryProductDetails(productIds);
        products = r.productDetails..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
        await iap.restorePurchases();
      }
    } catch (e) {
      _fail('$e');
    }
    notifyListeners();
  }

  ProductDetails? product(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> buy(String id) async {
    final p = product(id);
    if (p == null) return;
    error = null;
    busy = true;
    notifyListeners();
    try {
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
    } catch (e) {
      _fail('$e');
    }
  }

  Future<void> restore() async {
    if (!storeReady) return;
    busy = true;
    notifyListeners();
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      _fail('$e');
    }
    busy = false;
    notifyListeners();
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final d in list) {
      switch (d.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final ms = int.tryParse(d.transactionDate ?? '');
          await grant(d.productID, ms == null ? _now() : DateTime.fromMillisecondsSinceEpoch(ms));
          busy = false;
        case PurchaseStatus.error:
          _fail(d.error?.message ?? 'error');
        case PurchaseStatus.canceled:
          busy = false;
        case PurchaseStatus.pending:
          break;
      }
      if (d.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(d);
    }
    notifyListeners();
  }

  void _fail(String m) {
    error = m;
    busy = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
