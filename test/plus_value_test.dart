import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/features/plus/entitlement.dart';

void main() {
  test('sample value stack and yearly saving', () {
    expect(sampleTotalValue, 3443);
    expect(sampleYearlySavePct, 27);
    expect(rupees(1299), '₹1,299');
    expect(rupees(149), '₹149');
    expect(rupees(123456), '₹1,23,456');
  });
}
