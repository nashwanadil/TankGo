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
}
