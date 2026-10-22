import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fx.dart';
import 'market_models.dart';
import 'market_repository.dart';
import 'market_widgets.dart';

String categoryRoute(String name) => '/market/c/${Uri.encodeComponent(name)}';

/// Gradient art for a category banner/chip, from its primary dimension colour.
Gradient categoryGradient(MarketCategory c, Brightness b) {
  final a = c.primary.color(b);
  final z = c.dimensions.length > 1 ? c.dimensions[1].color(b) : Color.lerp(a, Colors.black, 0.5)!;
  return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a, Color.lerp(a, z, 0.6)!]);
}

/// "Shop by category" carousel: peeking, snapping pages; neighbours scale/fade with parallax art;
/// dots; auto-advance every few seconds that pauses while touched and is off under reduced motion.
class CategorySlider extends StatefulWidget {
  const CategorySlider({super.key, this.interval = const Duration(seconds: 4)});
  final Duration interval;
  @override
  State<CategorySlider> createState() => _CategorySliderState();
}

class _CategorySliderState extends State<CategorySlider> {
  final _cats = marketCategories();
  final _pc = PageController(viewportFraction: 0.84);
  Timer? _auto;
  bool _touching = false;
  int _page = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _auto?.cancel();
    _auto = reducedMotion(context) ? null : Timer.periodic(widget.interval, (_) => _advance());
  }

  void _advance() {
    if (!mounted || _touching || !_pc.hasClients || ScrollState.peek(context)) return;
    final next = (_page + 1) % _cats.length;
    if (next == 0) {
      _pc.jumpToPage(0);
    } else {
      _pc.animateToPage(next, duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _auto?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final still = reducedMotion(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 176,
        child: Listener(
          onPointerDown: (_) => _touching = true,
          onPointerUp: (_) => _touching = false,
          onPointerCancel: (_) => _touching = false,
          child: PageView.builder(
            key: const Key('category-slider'),
            controller: _pc,
            itemCount: _cats.length,
            padEnds: false,
            onPageChanged: (i) {
              Haptics.selection();
              setState(() => _page = i);
            },
            itemBuilder: (_, i) => AnimatedBuilder(
              animation: _pc,
              builder: (_, child) {
                final p = _pc.hasClients && _pc.position.haveDimensions ? (_pc.page ?? 0) : _page.toDouble();
                final d = (p - i).clamp(-1.0, 1.0);
                final s = still ? 1.0 : 1 - 0.08 * d.abs();
                return Transform.scale(
                  scale: s,
                  child: Opacity(opacity: still ? 1 : 1 - 0.35 * d.abs(), child: _Banner(c: _cats[i], parallax: still ? 0 : d)),
                );
              },
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < _cats.length; i++)
          AnimatedContainer(
            duration: motion(context, const Duration(milliseconds: 200)),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: i == _page ? 14 : 5,
            height: 5,
            decoration: BoxDecoration(
              color: i == _page ? t.colorScheme.primary : t.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ]),
    ]);
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.c, required this.parallax});
  final MarketCategory c;
  final double parallax;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: RepaintBoundary(
        child: Semantics(
          button: true,
          label: '${c.name}, ${c.primary.label}, ${c.count} sample items',
          child: GestureDetector(
            onTap: Haptics.tap(() => context.push(categoryRoute(c.name))),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: categoryGradient(c, t.brightness)),
                child: Stack(children: [
                  // Parallax art: the big icon drifts opposite to the swipe.
                  Positioned(
                    right: -24 + parallax * 40,
                    bottom: -28,
                    child: Transform.rotate(
                      angle: -math.pi / 14,
                      child: Icon(c.icon, size: 150, color: Colors.white.withOpacity(0.22)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                          child: Icon(c.icon, color: Colors.white, size: 22),
                        ),
                        const Spacer(),
                        const SampleBadge(),
                      ]),
                      const Spacer(),
                      Text(c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Flexible(child: _DimTag(c.primary, more: c.dimensions.length - 1)),
                        const SizedBox(width: 8),
                        Text('${c.count} items', style: t.textTheme.labelMedium?.copyWith(color: Colors.white)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DimTag extends StatelessWidget {
  const _DimTag(this.d, {this.more = 0});
  final WellnessDimension d;
  final int more;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(d.icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Flexible(
            child: Text(more > 0 ? '${d.label} +$more' : d.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

/// Quick-jump row of circular category chips.
class CategoryCircles extends StatelessWidget {
  const CategoryCircles({super.key});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cats = marketCategories();
    return SizedBox(
      height: 92,
      child: ListView.separated(
        key: const Key('category-circles'),
        scrollDirection: Axis.horizontal,
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = cats[i];
          return Semantics(
            button: true,
            label: c.name,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: Haptics.tap(() => context.push(categoryRoute(c.name))),
              child: SizedBox(
                width: 68,
                child: Column(children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: categoryGradient(c, t.brightness)),
                    child: Icon(c.icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 6),
                  Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: t.textTheme.labelSmall),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One category: header art, sort + dimension filters, product grid with add-to-cart / wishlist.
class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key, required this.name});
  final String name;
  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  CategorySort _sort = CategorySort.featured;
  WellnessDimension? _dim;

  static const _sortLabels = {
    CategorySort.featured: 'Featured',
    CategorySort.priceLow: 'Price: low to high',
    CategorySort.priceHigh: 'Price: high to low',
    CategorySort.name: 'Name A–Z',
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = categoryByName(widget.name);
    if (c == null) {
      return const MarketScaffold(title: 'Category', child: Center(child: Text('Category not found')));
    }
    final list = categoryProducts(c.name, dim: _dim, sort: _sort);
    return MarketScaffold(
      title: c.name,
      actions: const [CartButton()],
      child: CustomScrollView(slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Container(
                height: 120,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: categoryGradient(c, t.brightness)),
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                    child: Icon(c.icon, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, children: [for (final d in c.dimensions) _DimTag(d)]),
                    ]),
                  ),
                  const SampleBadge(),
                ]),
              ),
              const SizedBox(height: 10),
              Text('All items are SAMPLE placeholders with sample prices. $demoNote', style: t.textTheme.bodySmall),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView(key: const Key('category-sort'), scrollDirection: Axis.horizontal, children: [
                  for (final s in CategorySort.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_sortLabels[s]!),
                        selected: _sort == s,
                        onSelected: (_) {
                          Haptics.selection();
                          setState(() => _sort = s);
                        },
                      ),
                    ),
                ]),
              ),
              if (c.dimensions.length > 1)
                SizedBox(
                  height: 44,
                  child: ListView(key: const Key('category-dims'), scrollDirection: Axis.horizontal, children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('All dimensions'),
                        selected: _dim == null,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _dim = null),
                      ),
                    ),
                    for (final d in c.dimensions)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: Icon(d.icon, size: 16),
                          label: Text(d.label),
                          selected: _dim == d,
                          showCheckmark: false,
                          onSelected: (_) {
                            Haptics.selection();
                            setState(() => _dim = _dim == d ? null : d);
                          },
                        ),
                      ),
                  ]),
                ),
              const SizedBox(height: 6),
              Text('${list.length} sample items', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.62),
            itemCount: list.length,
            itemBuilder: (_, k) => _ShopCard(list[k]),
          ),
        ),
      ]),
    );
  }
}

class _ShopCard extends ConsumerWidget {
  const _ShopCard(this.p);
  final Product p;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inCart = ref.watch(marketProvider.select((s) => s.cart[p.id] ?? 0));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: ProductCard(p)),
      const SizedBox(height: 6),
      SizedBox(
        height: 40,
        child: p.consultOnly
            ? OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 8)),
                icon: const Icon(Icons.support_agent_rounded, size: 18),
                label: const FittedBox(child: Text('Consult first')),
                onPressed: Haptics.tap(() => context.push('/market/p/${p.id}')),
              )
            : FilledButton.icon(
                key: Key('add-${p.id}'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 8)),
                icon: Icon(inCart > 0 ? Icons.check_rounded : Icons.add_shopping_cart_rounded, size: 18),
                label: FittedBox(child: Text(inCart > 0 ? 'In cart ($inCart)' : 'Add to cart')),
                onPressed: Haptics.tap(() async {
                  final ok = inCart < 10 && await ref.read(marketProvider.notifier).add(p.id);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                        duration: const Duration(seconds: 2),
                        content: Text(ok ? 'Added to cart (demo)' : 'Cart limit reached for this item')));
                }),
              ),
      ),
    ]);
  }
}
