import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fx.dart';
import '../articles/data/article_repository.dart' show focusDimensionsProvider;
import 'market_models.dart';
import 'market_widgets.dart';
import 'market_category.dart';

/// Market tab: SAMPLE products for all eight wellness dimensions. Demo only.
class MarketPage extends ConsumerStatefulWidget {
  const MarketPage({super.key});
  @override
  ConsumerState<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends ConsumerState<MarketPage> {
  WellnessDimension? _dim;
  String? _cat;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final focus = ref.watch(focusDimensionsProvider);
    final rec = recommendedProducts(focus);
    final list = searchProducts(q: _q, dim: _dim, category: _cat);
    final cats = categoriesFor(_dim);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MeshBackground(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              sliver: SliverToBoxAdapter(
                child: Row(children: [
                  Expanded(child: Text('Market', style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800))),
                  IconButton(
                      tooltip: 'Wishlist',
                      onPressed: Haptics.tap(() => context.push('/market/wishlist')),
                      icon: const Icon(Icons.favorite_border_rounded)),
                  IconButton(
                      tooltip: 'Orders',
                      onPressed: Haptics.tap(() => context.push('/market/orders')),
                      icon: const Icon(Icons.receipt_long_outlined)),
                  const CartButton(),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  GlassCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.secondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Demo store: all items are SAMPLE placeholders with sample prices. $demoNote',
                            style: t.textTheme.bodySmall),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('market-search'),
                    onChanged: (v) => setState(() => _q = v),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search sample products',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      isDense: true,
                    ),
                  ),
                  if (_q.isEmpty) ...[
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: Text('Shop by category', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                      Text('${marketCategories().length} categories', style: t.textTheme.labelMedium),
                    ]),
                    const SizedBox(height: 8),
                  ],
                ]),
              ),
            ),
            if (_q.isEmpty) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(right: 4), child: CategorySlider())),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_q.isEmpty) ...[const SizedBox(height: 12), const CategoryCircles()],
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: ListView(scrollDirection: Axis.horizontal, children: [
                      _chip(
                          'All',
                          _dim == null,
                          () => setState(() {
                                _dim = null;
                                _cat = null;
                              })),
                      for (final d in WellnessDimension.values)
                        _chip(
                            d.label,
                            _dim == d,
                            () => setState(() {
                                  _dim = _dim == d ? null : d;
                                  _cat = null;
                                }),
                            icon: d.icon),
                    ]),
                  ),
                  if (_q.isEmpty && _dim == null && _cat == null) ...[
                    const SizedBox(height: 8),
                    Text('Recommended for your focus', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (rec.isEmpty)
                      Text('Complete an assessment to see items for your OneUP Focus areas.', style: t.textTheme.bodySmall)
                    else
                      SizedBox(
                        height: 190,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: rec.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (_, k) => SizedBox(width: 150, child: ProductCard(rec[k])),
                        ),
                      ),
                  ],
                  const SizedBox(height: 14),
                  Text(_dim == null ? 'Categories' : '${_dim!.label} categories',
                      style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (_dim == null)
                    SizedBox(
                        height: 48,
                        child: ListView(scrollDirection: Axis.horizontal, children: [
                          for (final c in cats)
                            Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(c),
                                  selected: _cat == c,
                                  onSelected: (_) {
                                    Haptics.selection();
                                    setState(() => _cat = _cat == c ? null : c);
                                  },
                                )),
                        ]))
                  else
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final c in cats)
                        Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(c),
                              selected: _cat == c,
                              onSelected: (_) {
                                Haptics.selection();
                                setState(() => _cat = _cat == c ? null : c);
                              },
                            )),
                    ]),
                  const SizedBox(height: 14),
                  Text('${list.length} sample items', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: list.isEmpty
                  ? SliverToBoxAdapter(child: Text('No sample items match.', style: t.textTheme.bodyMedium))
                  : SliverGrid.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.78),
                      itemCount: list.length,
                      itemBuilder: (_, k) => ProductCard(list[k]),
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap, {IconData? icon}) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          avatar: icon == null ? null : Icon(icon, size: 16),
          selected: sel,
          showCheckmark: false,
          onSelected: (_) {
            Haptics.selection();
            onTap();
          },
        ),
      );
}
