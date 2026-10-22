import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/services/haptics.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/features/market/market_category.dart';
import 'package:oneup/features/market/market_models.dart';
import 'package:oneup/features/market/market_repository.dart';
import 'mem_store.dart';

Widget _host(Widget child, MemStore s, {bool reduce = false}) => ProviderScope(
      overrides: [secureStoreProvider.overrideWithValue(s)],
      child: MaterialApp(
        home: Builder(builder: (c) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: reduce), child: child)),
      ),
    );

void main() {
  setUp(() => Haptics.enabled = false);

  test('categories cover all products and all 8 dimensions', () {
    final cats = marketCategories();
    expect(cats.map((c) => c.name).toSet().length, cats.length);
    expect(cats.fold<int>(0, (a, c) => a + c.count), catalog.length);
    expect(cats.expand((c) => c.dimensions).toSet(), WellnessDimension.values.toSet());
    expect(categoryByName('nope'), isNull);
  });

  test('category sort and dimension filter', () {
    final c = marketCategories().firstWhere((c) => c.dimensions.length > 1, orElse: () => marketCategories().first);
    final low = categoryProducts(c.name, sort: CategorySort.priceLow).where((p) => !p.consultOnly).map((p) => p.price).toList();
    expect(low, [...low]..sort());
    final high = categoryProducts(c.name, sort: CategorySort.priceHigh).where((p) => !p.consultOnly).map((p) => p.price).toList();
    expect(high, [...low.reversed]);
    final byName = categoryProducts(c.name, sort: CategorySort.name).map((p) => p.name.toLowerCase()).toList();
    expect(byName, [...byName]..sort());
    // consult-first items sort last on price low→high
    final sup = categoryProducts('Supplements', sort: CategorySort.priceLow);
    expect(sup.every((p) => p.consultOnly), isTrue);
    for (final d in c.dimensions) {
      expect(categoryProducts(c.name, dim: d).every((p) => p.dimension == d), isTrue);
    }
  });

  testWidgets('slider swipes with snapping, auto-advances, pauses on touch', (t) async {
    t.view.physicalSize = const Size(1080, 1920);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(const Scaffold(body: CategorySlider(interval: Duration(seconds: 2))), MemStore()));
    final cats = marketCategories();
    expect(find.text(cats.first.name), findsWidgets);
    PageController pc() => t.widget<PageView>(find.byKey(const Key('category-slider'))).controller!;
    await t.pump(const Duration(seconds: 2));
    await t.pump(const Duration(seconds: 1));
    expect(pc().page!.round(), 1, reason: 'auto-advanced');
    final g = await t.startGesture(t.getCenter(find.byKey(const Key('category-slider'))));
    await t.pump(const Duration(seconds: 3));
    expect(pc().page!.round(), 1, reason: 'paused while touched');
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(-25, 0));
      await t.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await t.pumpAndSettle();
    expect(pc().page, 2.0, reason: 'snapped to next page');
  });

  testWidgets('reduced motion: no auto-advance', (t) async {
    await t.pumpWidget(_host(const Scaffold(body: CategorySlider(interval: Duration(seconds: 1))), MemStore(), reduce: true));
    await t.pump(const Duration(seconds: 5));
    expect(t.widget<PageView>(find.byKey(const Key('category-slider'))).controller!.page, 0);
  });

  testWidgets('category screen: sort, filter, add to cart, consult-first', (t) async {
    t.view.physicalSize = const Size(1080, 1920);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final s = MemStore();
    late ProviderContainer c;
    await t.pumpWidget(ProviderScope(
      overrides: [secureStoreProvider.overrideWithValue(s)],
      child: Consumer(builder: (ctx, ref, _) {
        c = ProviderScope.containerOf(ctx);
        return const MaterialApp(home: CategoryScreen(name: 'Supplements'));
      }),
    ));
    await t.pump();
    expect(find.text('Consult first'), findsWidgets);
    expect(find.textContaining('Add to cart'), findsNothing);
    final cat = marketCategories().firstWhere((x) => x.name == 'Yoga');
    await t.pumpWidget(ProviderScope(
      overrides: [secureStoreProvider.overrideWithValue(s)],
      child: Consumer(builder: (ctx, ref, _) {
        c = ProviderScope.containerOf(ctx);
        return MaterialApp(home: CategoryScreen(name: cat.name));
      }),
    ));
    await t.pump();
    expect(find.text('${cat.count} sample items'), findsOneWidget);
    await t.dragUntilVisible(find.text('Price: high to low'), find.byKey(const Key('category-sort')), const Offset(-120, 0));
    await t.pumpAndSettle();
    await t.tap(find.text('Price: high to low'));
    await t.pump();
    final first = categoryProducts(cat.name, sort: CategorySort.priceHigh).first;
    await t.tap(find.byKey(Key('add-${first.id}')));
    await t.pump();
    expect(c.read(marketProvider).cart[first.id], 1);
    expect(find.text('In cart (1)'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('unknown category shows not found', (t) async {
    await t.pumpWidget(_host(const CategoryScreen(name: 'nope'), MemStore()));
    expect(find.text('Category not found'), findsOneWidget);
  });
}
