import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/features/home/home_page.dart';

void main() {
  test('home one-liner per band', () {
    expect(homeOneLiner(0, null), contains('all 8 dimensions'));
    expect(homeOneLiner(3, null), contains('remaining dimensions'));
    expect(homeOneLiner(8, 30), contains('small, steady steps'));
    expect(homeOneLiner(8, 69), contains('steady base'));
    expect(homeOneLiner(8, 85), contains('strong place'));
  });
}
