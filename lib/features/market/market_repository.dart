import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/env.dart';
import '../../core/services/secure_store.dart';
import 'market_models.dart';

class MarketState {
  const MarketState({this.wishlist = const {}, this.cart = const {}, this.orders = const []});
  final Set<String> wishlist;
  final Map<String, int> cart;
  final List<Order> orders;

  int get cartCount => cart.values.fold(0, (a, b) => a + b);
  int get cartTotal => cart.entries.fold(0, (a, e) => a + (productById(e.key)?.price ?? 0) * e.value);

  MarketState copyWith({Set<String>? wishlist, Map<String, int>? cart, List<Order>? orders}) =>
      MarketState(wishlist: wishlist ?? this.wishlist, cart: cart ?? this.cart, orders: orders ?? this.orders);

  Map<String, dynamic> toJson() => {
        'wishlist': wishlist.toList(),
        'cart': cart,
        'orders': [for (final o in orders) o.toJson()]
      };
  factory MarketState.fromJson(Map<String, dynamic> j) => MarketState(
        wishlist: Set<String>.from(j['wishlist'] as List? ?? const []),
        cart: Map<String, int>.from(j['cart'] as Map? ?? const {}),
        orders: [for (final o in j['orders'] as List? ?? const []) Order.fromJson(o as Map<String, dynamic>)],
      );
}

final marketProvider = StateNotifierProvider<MarketController, MarketState>((ref) => MarketController(ref.read(secureStoreProvider)));

/// Wishlist, cart and demo orders. Stored locally; mirrored best-effort to Supabase when signed in.
class MarketController extends StateNotifier<MarketState> {
  MarketController(this._store, {this.remote = true}) : super(const MarketState()) {
    _load();
  }
  final SecureStore _store;
  final bool remote;
  static const key = 'market_v1';

  SupabaseClient? get _client {
    if (!remote || !Env.isConfigured) return null;
    final c = Supabase.instance.client;
    return c.auth.currentUser == null ? null : c;
  }

  Future<void> _load() async {
    final raw = await _store.read(key);
    if (raw != null && mounted) {
      try {
        state = MarketState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  Future<void> _save() => _store.write(key, jsonEncode(state.toJson()));

  Future<void> _remote(Future<void> Function(SupabaseClient c, String uid) f) async {
    final c = _client;
    if (c == null) return;
    try {
      await f(c, c.auth.currentUser!.id).timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  Future<void> toggleWish(String id) async {
    final on = !state.wishlist.contains(id);
    state = state.copyWith(wishlist: on ? {...state.wishlist, id} : ({...state.wishlist}..remove(id)));
    await _save();
    await _remote((c, uid) async => on
        ? await c.from('market_wishlist').upsert({'user_id': uid, 'product_id': id})
        : await c.from('market_wishlist').delete().eq('product_id', id));
  }

  /// Consult-only items can never enter the cart.
  Future<bool> setQty(String id, int qty) async {
    final p = productById(id);
    if (p == null || p.consultOnly) return false;
    final q = qty.clamp(0, 10);
    final cart = {...state.cart};
    q == 0 ? cart.remove(id) : cart[id] = q;
    state = state.copyWith(cart: cart);
    await _save();
    await _remote((c, uid) async => q == 0
        ? await c.from('market_cart').delete().eq('product_id', id)
        : await c.from('market_cart').upsert({'user_id': uid, 'product_id': id, 'qty': q}));
    return true;
  }

  Future<bool> add(String id) => setQty(id, (state.cart[id] ?? 0) + 1);

  /// Demo checkout: no payment is taken. Clears the cart and records a demo order.
  Future<Order?> placeDemoOrder({required String name, required String city, DateTime? now}) async {
    if (state.cart.isEmpty) return null;
    final t = now ?? DateTime.now();
    final o = Order(
        id: 'DEMO-${t.millisecondsSinceEpoch % 1000000}',
        lines: {...state.cart},
        total: state.cartTotal,
        createdAt: t,
        name: name,
        city: city);
    state = state.copyWith(cart: {}, orders: [o, ...state.orders]);
    await _save();
    await _remote((c, uid) async {
      await c.from('market_orders').insert({'user_id': uid, 'demo_ref': o.id, 'lines': o.lines, 'total_sample': o.total, 'city': city});
      await c.from('market_cart').delete().eq('user_id', uid);
    });
    return o;
  }
}
