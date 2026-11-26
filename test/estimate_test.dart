import 'package:flutter_test/flutter_test.dart';
import 'package:fuelprices/data.dart';

Entry _e(double p) => Entry(DateTime(2026, 11, 23), {'e95': p}, null, 'EUR', 'L', 'weekly', 'test');

Series _h(List<double> weekly) => Series('EUR', 'L', [
  for (var i = 0; i < weekly.length; i++) (DateTime(2026, 11, 23).subtract(Duration(days: 7 * (weekly.length - 1 - i))), weekly[i]),
]);

void main() {
  test('carries the price forward with the average daily change of the last 4 weeks', () {
    // -2.8 ct over 28 days = -0.1 ct/day; 3 days later -> -0.3 ct.
    final est = estimateNow(_e(1.572), 'e95', _h([1.600, 1.593, 1.586, 1.579, 1.572]), DateTime(2026, 11, 26))!;
    expect(est, closeTo(1.569, 1e-9));
  });

  test('same day equals the official price', () {
    expect(estimateNow(_e(1.572), 'e95', _h([1.600, 1.586, 1.572]), DateTime(2026, 11, 23)), closeTo(1.572, 1e-9));
  });

  test('hidden without enough history', () {
    expect(estimateNow(_e(1.5), 'e95', null, DateTime(2026, 11, 26)), isNull);
    expect(estimateNow(_e(1.5), 'e95', _h([1.6, 1.5]), DateTime(2026, 11, 26)), isNull);
  });

  test('change is capped at 5 %', () {
    final est = estimateNow(_e(1.0), 'e95', _h([2.0, 1.5, 1.0]), DateTime(2026, 12, 7))!;
    expect(est, closeTo(0.95, 1e-9));
  });
}
