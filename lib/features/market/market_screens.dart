import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/haptics.dart';
import '../../core/widgets/fx.dart';
import 'market_models.dart';
import 'market_repository.dart';
import 'market_widgets.dart';

class ProductScreen extends ConsumerWidget {
  const ProductScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final p = productById(id);
    if (p == null) return const MarketScaffold(title: 'Product', child: Center(child: Text('Item not found.')));
    final s = ref.watch(marketProvider);
    final wish = s.wishlist.contains(p.id);
    final inCart = s.cart[p.id] ?? 0;
    final c = ref.read(marketProvider.notifier);
    return MarketScaffold(
      title: p.category,
      actions: const [CartButton()],
      bottom: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: p.consultOnly
              ? FilledButton.icon(
                  key: const Key('request-consult'),
                  icon: const Icon(Icons.support_agent_rounded),
                  label: const Text('Request via Consult'),
                  onPressed: Haptics.tap(() => context.go('/consult')),
                )
              : Row(children: [
                  IconButton.outlined(
                    tooltip: wish ? 'Remove from wishlist' : 'Add to wishlist',
                    icon: Icon(wish ? Icons.favorite_rounded : Icons.favorite_border_rounded),
                    onPressed: Haptics.tap(() => c.toggleWish(p.id)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('add-to-cart'),
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: Text(inCart == 0 ? 'Add to cart' : 'Add another ($inCart in cart)'),
                      onPressed: () async {
                        Haptics.success();
                        await c.add(p.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(const SnackBar(content: Text('Added to cart (demo)'), duration: Duration(seconds: 1)));
                        }
                      },
                    ),
                  ),
                ]),
        ),
      ),
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        AspectRatio(aspectRatio: 1.5, child: ProductArt(p, size: 96, radius: 28)),
        const SizedBox(height: 16),
        Text(p.name, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Row(children: [
          Icon(p.dimension.icon, size: 16, color: p.dimension.color(t.brightness)),
          const SizedBox(width: 6),
          Text('${p.dimension.label} · ${p.category}', style: t.textTheme.bodySmall),
        ]),
        const SizedBox(height: 10),
        Text(p.priceLabel, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Text(p.blurb, style: t.textTheme.bodyLarge),
        const SizedBox(height: 16),
        if (p.consultOnly)
          GlassCard(
            key: const Key('consult-note'),
            child: Row(children: [
              const Icon(Icons.health_and_safety_rounded),
              const SizedBox(width: 10),
              Expanded(child: Text(consultNote, style: t.textTheme.bodyMedium)),
            ]),
          ),
        if (p.consultOnly) const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.all(12),
          child: Text('$sampleNote ${p.consultOnly ? '' : demoNote}', style: t.textTheme.bodySmall),
        ),
      ]),
    );
  }
}

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final s = ref.watch(marketProvider);
    final c = ref.read(marketProvider.notifier);
    final lines = s.cart.entries.where((e) => productById(e.key) != null).toList();
    return MarketScaffold(
      title: 'Cart',
      bottom: lines.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(child: Text('Total (sample)', style: t.textTheme.titleMedium)),
                    Text(rupees(s.cartTotal), style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('to-checkout'),
                      onPressed: Haptics.tap(() => context.push('/market/checkout')),
                      child: const Text('Demo checkout'),
                    ),
                  ),
                ]),
              ),
            ),
      child: lines.isEmpty
          ? Center(child: Text('Your cart is empty.', style: t.textTheme.bodyLarge))
          : ListView(padding: const EdgeInsets.all(16), children: [
              for (final e in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    padding: const EdgeInsets.all(10),
                    child: Row(children: [
                      SizedBox(width: 64, height: 64, child: ProductArt(productById(e.key)!, size: 28, radius: 14)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(productById(e.key)!.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.textTheme.titleSmall),
                          Text(productById(e.key)!.priceLabel, style: t.textTheme.bodySmall),
                        ]),
                      ),
                      IconButton(
                          tooltip: 'Decrease',
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: Haptics.tap(() => c.setQty(e.key, e.value - 1))),
                      Text('${e.value}', style: t.textTheme.titleMedium),
                      IconButton(
                          tooltip: 'Increase',
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: Haptics.tap(() => c.setQty(e.key, e.value + 1))),
                    ]),
                  ),
                ),
              Text(demoNote, textAlign: TextAlign.center, style: t.textTheme.bodySmall),
            ]),
    );
  }
}

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _city = TextEditingController(), _pin = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _place() async {
    if (!_form.currentState!.validate()) {
      Haptics.error();
      return;
    }
    setState(() => _busy = true);
    final o = await ref.read(marketProvider.notifier).placeDemoOrder(name: _name.text.trim(), city: _city.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (o == null) return;
    Haptics.success();
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, size: 40),
        title: const Text('Demo order placed'),
        content: Text('Reference ${o.id}. $demoNote Nothing will be shipped.'),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('OK'))],
      ),
    );
    if (mounted) context.pushReplacement('/market/orders');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = ref.watch(marketProvider);
    String? req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
    return MarketScaffold(
      title: 'Demo checkout',
      child: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          GlassCard(
            key: const Key('demo-banner'),
            child: Row(children: [
              const Icon(Icons.money_off_rounded),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('$demoNote No card or UPI details are asked for, and nothing will be delivered.',
                      style: t.textTheme.bodyMedium)),
            ]),
          ),
          const SizedBox(height: 16),
          TextFormField(key: const Key('co-name'), controller: _name, validator: req, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 10),
          TextFormField(key: const Key('co-city'), controller: _city, validator: req, decoration: const InputDecoration(labelText: 'City')),
          const SizedBox(height: 10),
          TextFormField(
            key: const Key('co-pin'),
            controller: _pin,
            keyboardType: TextInputType.number,
            maxLength: 6,
            validator: (v) => RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '') ? null : 'Enter a 6-digit PIN code',
            decoration: const InputDecoration(labelText: 'PIN code (demo)'),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text('${s.cartCount} items · total (sample)', style: t.textTheme.bodyMedium)),
            Text(rupees(s.cartTotal), style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('place-order'),
            onPressed: _busy || s.cart.isEmpty ? null : _place,
            child: Text(_busy ? 'Placing…' : 'Place demo order'),
          ),
        ]),
      ),
    );
  }
}

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key, this.now});
  final DateTime? now;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final orders = ref.watch(marketProvider.select((s) => s.orders));
    final at = now ?? DateTime.now();
    return MarketScaffold(
      title: 'Orders (demo)',
      child: orders.isEmpty
          ? Center(child: Text('No demo orders yet.', style: t.textTheme.bodyLarge))
          : ListView(padding: const EdgeInsets.all(16), children: [
              for (final o in orders)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(
                            child: Text(o.id,
                                overflow: TextOverflow.ellipsis, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                        Chip(label: Text(o.statusAt(at)), visualDensity: VisualDensity.compact),
                      ]),
                      Text('${o.createdAt.day}/${o.createdAt.month}/${o.createdAt.year} · ${o.city}', style: t.textTheme.bodySmall),
                      const SizedBox(height: 6),
                      for (final e in o.lines.entries)
                        Text('${e.value} × ${productById(e.key)?.name ?? e.key}', style: t.textTheme.bodyMedium),
                      const SizedBox(height: 6),
                      Text('Total ${rupees(o.total)} (sample) · $demoNote', style: t.textTheme.bodySmall),
                    ]),
                  ),
                ),
            ]),
    );
  }
}

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final ids = ref.watch(marketProvider.select((s) => s.wishlist));
    final items = [
      for (final p in catalog)
        if (ids.contains(p.id)) p
    ];
    return MarketScaffold(
      title: 'Wishlist',
      actions: const [CartButton()],
      child: items.isEmpty
          ? Center(child: Text('Tap the heart on any item to save it here.', style: t.textTheme.bodyLarge))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.78),
              itemCount: items.length,
              itemBuilder: (_, k) => ProductCard(items[k]),
            ),
    );
  }
}
