import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/features/market/market_models.dart';

/// The server-side `products` seed must mirror the in-app SAMPLE catalogue, otherwise the
/// consult-only cart guard (market_cart_guard) and the app disagree about what exists.
void main() {
  const s = r"'((?:[^']|'')*)'";
  final row = RegExp('^\\s*\\($s, $s, $s, $s, $s, (\\d+), (true|false)\\)[,]?\$', multiLine: true);
  String u(String x) => x.replaceAll("''", "'");

  test('market seed migration matches catalog', () {
    final sql = File('supabase/migrations/20261022080000_market_seed.sql').readAsStringSync();
    final seeded = {
      for (final m in row.allMatches(sql))
        u(m[1]!): [u(m[2]!), u(m[3]!), u(m[4]!), u(m[5]!), int.parse(m[6]!), m[7] == 'true'],
    };
    expect(seeded.length, catalog.length, reason: 'row count differs from catalog');
    for (final p in catalog) {
      expect(seeded[p.id], [p.dimension.name, p.category, p.name, p.blurb, p.price, p.consultOnly],
          reason: 'seed row for ${p.id} is missing or differs from market_models.dart');
      expect(p.name, startsWith('SAMPLE '));
    }
  });
}
