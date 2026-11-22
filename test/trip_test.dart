import 'package:flutter_test/flutter_test.dart';
import 'package:fuelprices/trip.dart';

void main() {
  test('buys little before a cheaper country, fills up where cheapest', () {
    final plan = planTrip([const Leg('DE', 300), const Leg('AT', 300), const Leg('SI', 300)], {'DE': 2.0, 'AT': 1.8, 'SI': 1.6}, tank: 50, consumption: 10)!;
    // need 30 L per leg; start full (50 L). DE: cheaper AT within reach -> buy 0 (have 50, need 30).
    expect(plan.stops[0].litres, 0);
    // Leaving DE with 20 L; AT: SI cheaper & reachable (need 30) -> goal 30, buy 10.
    expect(plan.stops[1].litres, closeTo(10, 1e-9));
    // SI: last leg need 30, fuel 0 -> buy 30.
    expect(plan.stops[2].litres, closeTo(30, 1e-9));
    expect(plan.total, closeTo(10 * 1.8 + 30 * 1.6, 1e-9));
    expect(plan.saved, greaterThan(0));
  });

  test('fills the tank in the cheapest country when no cheaper one is in reach', () {
    final plan = planTrip([const Leg('LU', 100), const Leg('DE', 600)], {'LU': 1.5, 'DE': 1.9}, tank: 50, consumption: 10, startFull: false)!;
    expect(plan.stops[0].litres, closeTo(50, 1e-9)); // full tank in cheap LU
    expect(plan.stops[1].litres, closeTo(60 - 40, 1e-9)); // need 60 total in DE leg, 40 left
  });

  test('missing price or empty route returns null', () {
    expect(planTrip([], {}, tank: 50, consumption: 6), isNull);
    expect(planTrip([const Leg('XX', 10)], {}, tank: 50, consumption: 6), isNull);
  });

  test('neighbour map is symmetric enough and covers all EU codes', () {
    for (final e in neighbours.entries) {
      for (final n in e.value) {
        expect(neighbours.containsKey(n), true, reason: '${e.key}->$n');
      }
    }
  });

  test('no tiny fills: every purchase is at least 10 L (or zero)', () {
    final routes = [
      [const Leg('DE', 300), const Leg('AT', 350), const Leg('SI', 150), const Leg('HR', 400)],
      [const Leg('FR', 520), const Leg('ES', 80), const Leg('PT', 33)],
    ];
    final prices = {'DE': 1.8, 'AT': 1.7, 'SI': 1.55, 'HR': 1.5, 'FR': 1.9, 'ES': 1.5, 'PT': 1.7};
    for (final r in routes) {
      for (final km in [0.0, 5.0, 17.0]) {
        final plan = planTrip([...r, Leg('DE', km)], prices, tank: 50, consumption: 6.5)!;
        for (final st in plan.stops) {
          expect(st.litres == 0 || st.litres >= 10 - 1e-6, true, reason: '${st.cc} ${st.litres}');
        }
      }
    }
  });

  test('a country longer than one tank: refuel there and carry cheap fuel on (no 2 L stop)', () {
    // 800 km DE (52 L) with a 50 L tank, then 300 km NL (19.5 L), NL dearer: buy all extra fuel in DE.
    final plan = planTrip([const Leg('DE', 800), const Leg('NL', 300)], {'DE': 2.215, 'NL': 2.294}, tank: 50, consumption: 6.5)!;
    expect(plan.stops[0].litres, closeTo(21.5, 1e-6));
    expect(plan.stops[1].litres, 0);
  });
}
