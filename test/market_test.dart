import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oneup/core/services/haptics.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/features/market/market_models.dart';
import 'package:oneup/features/market/market_page.dart';
import 'package:oneup/features/market/market_repository.dart';
import 'package:oneup/features/market/market_screens.dart';
import 'mem_store.dart';

void main() {
  setUp(() => Haptics.enabled = false);

  test('catalog rules: SAMPLE only, 8-12 per dimension, consult-first meds', () {
    expect(catalog.map((p) => p.id).toSet().length, catalog.length);
    for (final d in WellnessDimension.values) {
      expect(catalog.where((p) => p.dimension == d).length, inInclusiveRange(8, 12), reason: d.name);
    }
    final banned = RegExp(r'\b(cure|cures|treat|treats|heal|heals|clinically|guaranteed|proven|dose|dosage|mg)\b', caseSensitive: false);
    for (final p in catalog) {
      expect(p.name.startsWith('SAMPLE '), isTrue, reason: p.id);
      expect(banned.hasMatch('${p.name} ${p.blurb}'), isFalse, reason: 'no claims: ${p.id}');
      if (p.consultOnly) {
        expect(p.price, 0);
        expect(p.priceLabel, 'Consult first');
      } else {
        expect(p.price, greaterThan(0));
        expect(p.priceLabel, endsWith('(sample)'));
      }
      if (RegExp('Medicine|Supplement').hasMatch(p.category)) expect(p.consultOnly, isTrue, reason: p.id);
      if (p.dimension == WellnessDimension.financial && p.category == 'Money courses') {
        expect(p.blurb, contains('Not financial advice'));
      }
    }
  });

  test('search, categories, recommendations', () {
    expect(searchProducts(q: 'yoga').map((p) => p.id), containsAll(['ph-yoga-mat', 'ph-yoga-blocks']));
    expect(categoriesFor(WellnessDimension.physical), containsAll(['Fitness gear', 'Yoga', 'Sleep', 'Nutrition']));
    final r = recommendedProducts([WellnessDimension.financial, WellnessDimension.environmental]);
    expect(r.length, 8);
    expect(r.first.dimension, WellnessDimension.financial);
    expect(r[1].dimension, WellnessDimension.environmental);
    expect(r.any((p) => p.consultOnly), isFalse);
    expect(recommendedProducts(const []), isEmpty);
  });

  test('cart, wishlist, demo order persist; consult-only refused', () async {
    final s = MemStore();
    final c = MarketController(s, remote: false);
    await Future<void>.delayed(Duration.zero);
    expect(await c.add('ph-medicine'), isFalse);
    await c.add('ph-yoga-mat');
    await c.add('ph-yoga-mat');
    await c.add('fi-jar');
    await c.toggleWish('sp-cushion');
    expect(c.state.cartCount, 3);
    expect(c.state.cartTotal, 999 * 2 + 249);
    await c.setQty('fi-jar', 0);
    expect(c.state.cart.containsKey('fi-jar'), isFalse);
    final o = await c.placeDemoOrder(name: 'A', city: 'Pune', now: DateTime(2026, 10, 1));
    expect(o!.total, 1998);
    expect(c.state.cart, isEmpty);
    expect(o.statusAt(DateTime(2026, 10, 1, 5)), 'Placed (demo)');
    expect(o.statusAt(DateTime(2026, 10, 2, 1)), 'Shipped (demo)');
    expect(o.statusAt(DateTime(2026, 10, 5)), 'Delivered (demo)');
    final c2 = MarketController(s, remote: false);
    await Future<void>.delayed(Duration.zero);
    expect(c2.state.orders.single.id, o.id);
    expect(c2.state.wishlist, {'sp-cushion'});
    expect(await c2.placeDemoOrder(name: 'A', city: 'B'), isNull);
  });

  Future<GoRouter> app(WidgetTester t, String start) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final r = GoRouter(initialLocation: start, routes: [
      GoRoute(path: '/market', builder: (_, __) => const MarketPage()),
      GoRoute(path: '/market/p/:id', builder: (_, s) => ProductScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/market/cart', builder: (_, __) => const CartScreen()),
      GoRoute(path: '/market/checkout', builder: (_, __) => const CheckoutScreen()),
      GoRoute(path: '/market/orders', builder: (_, __) => const OrdersScreen()),
      GoRoute(path: '/market/wishlist', builder: (_, __) => const WishlistScreen()),
      GoRoute(path: '/consult', builder: (_, __) => const Text('CONSULT')),
    ]);
    await t.pumpWidget(ProviderScope(
      overrides: [
        secureStoreProvider.overrideWithValue(MemStore()),
        marketProvider.overrideWith((ref) => MarketController(ref.read(secureStoreProvider), remote: false)),
      ],
      child: MaterialApp.router(routerConfig: r),
    ));
    await t.pumpAndSettle();
    return r;
  }

  testWidgets('home search filters the grid', (t) async {
    await app(t, '/market');
    expect(find.textContaining('Demo store'), findsOneWidget);
    await t.enterText(find.byKey(const Key('market-search')), 'compost');
    await t.pumpAndSettle();
    await t.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await t.pumpAndSettle();
    expect(find.text('1 sample items'), findsOneWidget);
    expect(find.text('SAMPLE Compost Bin'), findsOneWidget);
  });

  testWidgets('product -> cart -> demo checkout -> orders', (t) async {
    final r = await app(t, '/market/p/ph-yoga-mat');
    expect(find.text('SAMPLE Yoga Mat'), findsOneWidget);
    expect(find.text('₹999 (sample)'), findsOneWidget);
    await t.tap(find.byKey(const Key('add-to-cart')));
    await t.pumpAndSettle();
    r.push('/market/cart');
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Increase'));
    await t.pumpAndSettle();
    expect(find.text('₹1998'), findsOneWidget);
    await t.tap(find.byKey(const Key('to-checkout')));
    await t.pumpAndSettle();
    expect(find.textContaining('Demo — no payment taken'), findsWidgets);
    await t.tap(find.byKey(const Key('place-order')));
    await t.pumpAndSettle();
    expect(find.text('Required'), findsNWidgets(2));
    await t.enterText(find.byKey(const Key('co-name')), 'Asha');
    await t.enterText(find.byKey(const Key('co-city')), 'Pune');
    await t.enterText(find.byKey(const Key('co-pin')), '411001');
    await t.tap(find.byKey(const Key('place-order')));
    await t.pumpAndSettle();
    expect(find.text('Demo order placed'), findsOneWidget);
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(find.text('Orders (demo)'), findsOneWidget);
    expect(find.text('Placed (demo)'), findsOneWidget);
    expect(find.text('2 × SAMPLE Yoga Mat'), findsOneWidget);
  });

  testWidgets('consult-only item: no add-to-cart, consult note, routes to Consult', (t) async {
    await app(t, '/market/p/ph-medicine');
    expect(find.byKey(const Key('add-to-cart')), findsNothing);
    expect(find.textContaining('Consult a qualified professional before use'), findsOneWidget);
    await t.tap(find.byKey(const Key('request-consult')));
    await t.pumpAndSettle();
    expect(find.text('CONSULT'), findsOneWidget);
  });
}
