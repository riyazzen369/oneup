import '../plus/entitlement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/haptics.dart';
import '../../core/widgets/fx.dart';
import 'market_models.dart';
import 'market_repository.dart';

/// Placeholder product art: dimension gradient + icon (no real photos).
class ProductArt extends StatelessWidget {
  const ProductArt(this.p, {super.key, this.size = 44, this.radius = 16});
  final Product p;
  final double size, radius;
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final c = p.dimension.color(b);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.withOpacity(0.85), c.withOpacity(0.35)]),
      ),
      child: Stack(children: [
        Center(child: Icon(p.icon, size: size, color: Colors.white)),
        const Positioned(top: 8, left: 8, child: SampleBadge()),
      ]),
    );
  }
}

class SampleBadge extends StatelessWidget {
  const SampleBadge({super.key, this.label = 'SAMPLE'});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
      );
}

class ProductCard extends ConsumerWidget {
  const ProductCard(this.p, {super.key});
  final Product p;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final wish = ref.watch(marketProvider.select((s) => s.wishlist.contains(p.id)));
    return PressScale(
      semanticLabel: '${p.name}, ${p.priceLabel}',
      onTap: Haptics.tap(() => context.push('/market/p/${p.id}')),
      child: GlassCard(
        padding: const EdgeInsets.all(8),
        radius: 20,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(children: [
              Positioned.fill(child: ProductArt(p)),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  tooltip: wish ? 'Remove from wishlist' : 'Add to wishlist',
                  icon: Icon(wish ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: Colors.white),
                  onPressed: Haptics.tap(() => ref.read(marketProvider.notifier).toggleWish(p.id)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          Text(p.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.15)),
          const SizedBox(height: 2),
          if (ref.watch(isPlusProvider) && !p.consultOnly)
            Row(children: [
              Flexible(
                child: Text('₹${memberPrice(p.price)} member',
                    key: Key('member-price-${p.id}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFFB7811A))),
              ),
              const SizedBox(width: 4),
              Text('₹${p.price}', style: t.textTheme.labelSmall?.copyWith(decoration: TextDecoration.lineThrough)),
            ])
          else
            Text(p.priceLabel, style: t.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

/// Cart icon with count badge.
class CartButton extends ConsumerWidget {
  const CartButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(marketProvider.select((s) => s.cartCount));
    return IconButton(
      tooltip: 'Cart',
      onPressed: Haptics.tap(() => context.push('/market/cart')),
      icon: Badge(isLabelVisible: n > 0, label: Text('$n'), child: const Icon(Icons.shopping_cart_outlined)),
    );
  }
}

/// Plain scaffold for market sub-screens.
class MarketScaffold extends StatelessWidget {
  const MarketScaffold({super.key, required this.title, required this.child, this.actions = const [], this.bottom});
  final String title;
  final Widget child;
  final List<Widget> actions;
  final Widget? bottom;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(title: Text(title), backgroundColor: Colors.transparent, actions: actions),
        bottomNavigationBar: bottom == null
            ? null
            : Material(
                color: Theme.of(context).colorScheme.surfaceContainerHigh.withOpacity(0.96),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: bottom,
              ),
        extendBody: true,
        body: MeshBackground(child: SafeArea(bottom: false, child: child)),
      );
}

String rupees(int v) => '₹$v';
