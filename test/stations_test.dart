import 'package:flutter_test/flutter_test.dart';
import 'package:fuelprices/stations.dart';

Station st(String id, double lat, double lon, {double? e95, double? diesel}) => Station(id, id, '', '', lat, lon, {'e95': ?e95, 'diesel': ?diesel}, null);

void main() {
  test('haversine', () {
    expect(haversineKm(48.8566, 2.3522, 48.8566, 2.3522), 0);
    // Paris - Lyon is about 392 km
    expect(haversineKm(48.8566, 2.3522, 45.7640, 4.8357), closeTo(392, 3));
    // one degree of latitude is about 111.2 km
    expect(haversineKm(0, 0, 1, 0), closeTo(111.2, 0.3));
  });

  test('countriesAt', () {
    expect(countriesAt(48.85, 2.35), ['FR']);
    expect(countriesAt(40.4, -3.7), ['ES']);
    expect(countriesAt(41.9, 12.5), ['IT']);
    expect(countriesAt(52.5, 13.4), isEmpty); // Berlin
    expect(countriesAt(43.4, 6.9), containsAll(['FR'])); // Riviera
  });

  test('filter by radius and fuel, sort by price / distance, cheapest', () {
    const lat = 48.0, lon = 2.0;
    final all = [
      st('near', 48.01, 2.0, e95: 1.90), // ~1.1 km
      st('mid', 48.05, 2.0, e95: 1.80), // ~5.6 km
      st('far', 48.2, 2.0, e95: 1.50), // ~22 km
      st('nofuel', 48.0, 2.01, diesel: 1.7),
      st('tie', 48.02, 2.0, e95: 1.80), // ~2.2 km, ties with mid
    ];
    final r10 = nearbyStations(all, lat: lat, lon: lon, fuel: 'e95', radiusKm: 10);
    expect(r10.map((h) => h.station.id), ['tie', 'mid', 'near']); // price asc, tie -> nearer first
    expect(nearbyStations(all, lat: lat, lon: lon, fuel: 'e95', radiusKm: 5).map((h) => h.station.id), ['tie', 'near']);
    expect(nearbyStations(all, lat: lat, lon: lon, fuel: 'e95', radiusKm: 25).map((h) => h.station.id).first, 'far');
    expect(nearbyStations(all, lat: lat, lon: lon, fuel: 'e95', radiusKm: 10, sort: StationSort.distance).map((h) => h.station.id), ['near', 'tie', 'mid']);
    expect(nearbyStations(all, lat: lat, lon: lon, fuel: 'diesel', radiusKm: 10).map((h) => h.station.id), ['nofuel']);
    expect(nearbyStations(all, lat: lat, lon: lon, fuel: 'lpg', radiusKm: 25), isEmpty);
    expect(cheapest(r10)!.station.id, 'tie');
    expect(cheapest(const []), isNull);
  });

  test('parse file rows with null prices and bad rows', () {
    final f = StationFile.fromJson({
      'cc': 'FR',
      'updated': '2026-11-21T10:05:00Z',
      'source': 'src',
      's': [
        ['1', 'Total', '1 rue X', 'Paris', 48.8, 2.3, 1.9, null, 0.9, '2026-11-20'],
        ['bad'],
      ],
    });
    expect(f.stations.length, 1);
    expect(f.stations.first.prices, {'e95': 1.9, 'lpg': 0.9});
    expect(f.stations.first.date, DateTime(2026, 11, 20));
    expect(f.source, 'src');
  });
}
