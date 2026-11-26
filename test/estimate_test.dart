import 'package:flutter_test/flutter_test.dart';
import 'package:fuelprices/data.dart';

Entry _e(String date, {String cur = 'EUR', String unit = 'L', double p = 1.70, String freq = 'weekly'}) =>
    Entry(DateTime.parse(date), {'e95': p}, null, cur, unit, freq, 'test');

Signal _s(double Function(int day) eurL) => Signal('flat', 0, {
  for (var d = 1; d <= 30; d++) DateTime.utc(2026, 11, d): {'eur_l': eurL(d), 'usd_gal': eurL(d) * 4.4},
});

void main() {
  final now = DateTime(2026, 11, 26);

  test('adds crude change since the window that shaped the weekly price', () {
    // Bulletin dated 23.11 -> reference window 9..16.11 at 0.50, days after 16.11 at 0.45.
    final s = _s((d) => d >= 17 ? 0.45 : 0.50);
    final est = estimateNow(_e('2026-11-23'), 'e95', s, now)!;
    expect(est, closeTo(1.65, 1e-9));
  });

  test('hidden when crude did not move', () {
    expect(estimateNow(_e('2026-11-23'), 'e95', _s((_) => 0.5), now), isNull);
  });

  test('hidden for fresh, old, daily or other-currency prices', () {
    final s = _s((d) => d >= 17 ? 0.45 : 0.50);
    expect(estimateNow(_e('2026-11-25'), 'e95', s, now), isNull);
    expect(estimateNow(_e('2026-11-01'), 'e95', s, now), isNull);
    expect(estimateNow(_e('2026-11-23', freq: 'daily'), 'e95', s, now), isNull);
    expect(estimateNow(_e('2026-11-23', cur: 'PLN'), 'e95', s, now), isNull);
  });

  test('change is capped at 8 % of the price', () {
    final est = estimateNow(_e('2026-11-23'), 'e95', _s((d) => d >= 17 ? 0.10 : 0.50), now)!;
    expect(est, closeTo(1.70 * 0.92, 1e-9));
  });

  test('US prices use the per-gallon crude series', () {
    final est = estimateNow(_e('2026-11-23', cur: 'USD', unit: 'gal', p: 3.20), 'e95', _s((d) => d >= 17 ? 0.45 : 0.50), now)!;
    expect(est, closeTo(3.20 - 0.05 * 4.4, 1e-9));
  });
}
