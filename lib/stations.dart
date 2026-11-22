import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// Countries with station-level prices, with a coarse bounding box
/// (south, west, north, east) including islands. Boxes overlap near borders.
const stationCountries = <String, (double, double, double, double)>{
  'FR': (41.3, -5.2, 51.2, 9.6),
  'ES': (27.5, -18.3, 43.9, 4.4),
  'IT': (35.4, 6.6, 47.1, 18.6),
};

const stationFuels = ['e95', 'diesel', 'lpg'];

/// Country codes whose bounding box contains the point (usually 0 or 1, two near borders).
List<String> countriesAt(double lat, double lon) => [
  for (final e in stationCountries.entries)
    if (lat >= e.value.$1 && lat <= e.value.$3 && lon >= e.value.$2 && lon <= e.value.$4) e.key,
];

class Station {
  final String id, name, address, city;
  final double lat, lon;
  final Map<String, double> prices; // fuel key -> EUR/L (missing = not sold)
  final DateTime? date;
  const Station(this.id, this.name, this.address, this.city, this.lat, this.lon, this.prices, this.date);

  /// Row layout: [id,name,address,city,lat,lon,e95,diesel,lpg,"YYYY-MM-DD"].
  factory Station.fromRow(List r) {
    String s(int i) => r[i]?.toString() ?? '';
    double? d(int i) => i < r.length && r[i] is num ? (r[i] as num).toDouble() : null;
    final prices = <String, double>{};
    for (var i = 0; i < stationFuels.length; i++) {
      final v = d(6 + i);
      if (v != null && v > 0) prices[stationFuels[i]] = v;
    }
    return Station(s(0), s(1), s(2), s(3), (r[4] as num).toDouble(), (r[5] as num).toDouble(), prices, r.length > 9 && r[9] != null ? DateTime.tryParse(r[9].toString()) : null);
  }
}

class StationFile {
  final String cc, updated, source;
  final List<Station> stations;
  const StationFile(this.cc, this.updated, this.source, this.stations);

  factory StationFile.fromJson(Map j) {
    final out = <Station>[];
    for (final r in (j['s'] as List? ?? const [])) {
      try {
        out.add(Station.fromRow(r as List));
      } catch (_) {} // skip malformed rows
    }
    return StationFile((j['cc'] ?? '') as String, (j['updated'] ?? '') as String, (j['source'] ?? '') as String, out);
  }
}

/// Decodes a country file; top-level so it can run in an isolate.
StationFile parseStationFile(Uint8List bytes) => StationFile.fromJson(jsonDecode(utf8.decode(bytes)) as Map);

class Hit {
  final Station station;
  final double km, price;
  const Hit(this.station, this.km, this.price);
}

double _rad(double d) => d * math.pi / 180;

/// Great-circle distance in kilometres.
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _rad(lat2 - lat1), dLon = _rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) + math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 12742 * math.asin(math.min(1.0, math.sqrt(a)));
}

enum StationSort { price, distance, newest }

/// Stations within [radiusKm] that sell [fuel], sorted by price, distance or last update (newest first).
List<Hit> nearbyStations(List<Station> all, {required double lat, required double lon, required String fuel, required double radiusKm, StationSort sort = StationSort.price}) {
  final out = <Hit>[];
  for (final s in all) {
    final p = s.prices[fuel];
    if (p == null) continue;
    final km = haversineKm(lat, lon, s.lat, s.lon);
    if (km <= radiusKm) out.add(Hit(s, km, p));
  }
  int byDate(Hit a, Hit b) {
    final x = a.station.date, y = b.station.date;
    if (x == null || y == null) return x == null && y == null ? 0 : (x == null ? 1 : -1);
    return y.compareTo(x); // newest first
  }

  out.sort((a, b) {
    final c = switch (sort) {
      StationSort.price => a.price.compareTo(b.price),
      StationSort.distance => a.km.compareTo(b.km),
      StationSort.newest => byDate(a, b),
    };
    if (c != 0) return c;
    return sort == StationSort.price ? a.km.compareTo(b.km) : a.price.compareTo(b.price);
  });
  return out;
}

/// The cheapest hit (nearest on ties), or null when empty.
Hit? cheapest(List<Hit> hits) {
  Hit? best;
  for (final h in hits) {
    if (best == null || h.price < best.price || (h.price == best.price && h.km < best.km)) best = h;
  }
  return best;
}

/// The nearest hit (cheapest on ties), or null when empty.
Hit? nearest(List<Hit> hits) {
  Hit? best;
  for (final h in hits) {
    if (best == null || h.km < best.km || (h.km == best.km && h.price < best.price)) best = h;
  }
  return best;
}
