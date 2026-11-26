import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'stations.dart';

const dataBase = String.fromEnvironment('DATA_BASE', defaultValue: 'https://tankgo.nashwanadil.com');
const galToL = 3.78541;

class Entry {
  final DateTime date;
  final Map<String, double> prices;
  final Map<String, double>? prev;
  final String currency, unit, frequency, source;
  Entry(this.date, this.prices, this.prev, this.currency, this.unit, this.frequency, this.source);

  static Map<String, double> _m(Map v) => {for (final e in v.entries) e.key as String: (e.value as num).toDouble()};

  factory Entry.fromJson(Map j) => Entry(DateTime.parse(j['date']), _m(j['prices']), j['prev'] == null ? null : _m(j['prev']), j['currency'], j['unit'], j['frequency'], j['source']);

  /// Price per litre (converts US gallon prices).
  double perLitre(double v) => unit == 'gal' ? v / galToL : v;
}

class Series {
  final String currency, unit;
  final List<(DateTime, double)> points;
  Series(this.currency, this.unit, this.points);
}

/// Indicative price outlook derived from crude oil (Brent) and EUR/USD.
class Signal {
  final String direction; // up | down | flat
  final double deltaCt; // crude cost change in ct/L over ~2 weeks
  /// Daily crude cost per pump unit: date -> {'eur_l': .., 'usd_gal': ..}.
  final Map<DateTime, Map<String, double>> crude;
  Signal(this.direction, this.deltaCt, [this.crude = const {}]);
}

/// Estimated pump price for today, from the latest weekly price plus the change in crude cost
/// between the window that shaped that price and the crude days after it.
/// Pump prices follow crude with a lag of about one to two weeks, so the weekly price dated D
/// reflects crude around D-14..D-7. Returns null when the estimate adds nothing or cannot be made.
double? estimateNow(Entry e, String fuel, Signal s, DateTime now) {
  final price = e.prices[fuel];
  if (price == null || e.frequency != 'weekly') return null;
  final age = _dayDiff(e.date, now);
  if (age < 2 || age > 14) return null;
  final key = e.currency == 'USD' && e.unit == 'gal'
      ? 'usd_gal'
      : e.currency == 'EUR' && e.unit == 'L'
      ? 'eur_l'
      : null;
  if (key == null) return null;
  final pts = [
    for (final c in s.crude.entries)
      if (c.value[key] != null) (c.key, c.value[key]!),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  final from = e.date.subtract(const Duration(days: 14)), to = e.date.subtract(const Duration(days: 7));
  final ref = [for (final p in pts) if (!p.$1.isBefore(from) && !p.$1.isAfter(to)) p.$2];
  final fresh = [for (final p in pts) if (p.$1.isAfter(to)) p.$2];
  if (ref.isEmpty || fresh.isEmpty) return null;
  double avg(List<double> v) => v.reduce((a, b) => a + b) / v.length;
  var delta = avg(fresh) - avg(ref);
  final cap = price * 0.08;
  delta = delta.clamp(-cap, cap);
  final perL = e.unit == 'gal' ? delta / galToL : delta;
  if (perL.abs() < 0.005) return null;
  return price + delta;
}

int _dayDiff(DateTime a, DateTime b) => DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

class Loaded<T> {
  final T? value;
  final bool offline;
  Loaded(this.value, this.offline);
}

class Api {
  final http.Client client;
  Api([http.Client? c]) : client = c ?? http.Client();

  Future<Loaded<Map<String, dynamic>>> _get(String path, String cacheKey) async {
    SharedPreferences? p;
    try {
      p = await SharedPreferences.getInstance();
    } catch (_) {}
    try {
      final r = await client.get(Uri.parse('$dataBase/$path')).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final body = utf8.decode(r.bodyBytes);
      final j = jsonDecode(body) as Map<String, dynamic>;
      await p?.setString(cacheKey, body);
      return Loaded(j, false);
    } catch (_) {
      final c = p?.getString(cacheKey);
      if (c != null) return Loaded(jsonDecode(c) as Map<String, dynamic>, true);
      return Loaded(null, true);
    }
  }

  /// Remote switches (`v1/config.json`); the value is null when nothing could be read (then nothing changes).
  Future<Loaded<Map<String, dynamic>>> config() => _get('v1/config.json', 'config');

  Future<Loaded<Map<String, Entry>>> latest() async {
    final r = await _get('v1/latest.json', 'latest');
    final c = r.value?['countries'] as Map?;
    if (c == null) return Loaded(null, true);
    return Loaded({for (final e in c.entries) e.key as String: Entry.fromJson(e.value as Map)}, r.offline);
  }

  Future<Signal?> signal() async {
    final j = (await _get('v1/signal.json', 'signal')).value;
    if (j == null || j['direction'] == null) return null;
    final crude = <DateTime, Map<String, double>>{};
    for (final c in ((j['crude'] as Map?) ?? const {}).entries) {
      crude[DateTime.parse(c.key as String)] = {for (final f in (c.value as Map).entries) f.key as String: (f.value as num).toDouble()};
    }
    return Signal(j['direction'] as String, (j['delta_ct_l'] as num).toDouble(), crude);
  }

  /// History per fuel key for one country.
  Future<Map<String, Series>> historyAll(String cc) async {
    final j = (await _get('v1/history/$cc.json', 'hist_$cc')).value;
    if (j == null) return {};
    final out = <String, List<(DateTime, double)>>{};
    for (final e in (j['points'] as Map).entries) {
      final d = DateTime.parse(e.key as String);
      for (final f in (e.value as Map).entries) {
        out.putIfAbsent(f.key as String, () => []).add((d, (f.value as num).toDouble()));
      }
    }
    return {for (final e in out.entries) e.key: Series(j['currency'], j['unit'], e.value..sort((a, b) => a.$1.compareTo(b.$1)))};
  }

  final _stationCache = <String, StationFile>{};

  /// Station list per country (whole file; callers filter on the device). Throws on network/parse errors.
  /// Big files are parsed in an isolate; results are kept in memory only.
  Future<StationFile> stations(String cc, {bool refresh = false}) async {
    if (!refresh && _stationCache[cc] != null) return _stationCache[cc]!;
    final r = await client.get(Uri.parse('$dataBase/v1/stations/$cc.json')).timeout(const Duration(seconds: 60));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    final bytes = r.bodyBytes;
    final f = bytes.length > 200000 ? await compute<Uint8List, StationFile>(parseStationFile, bytes) : parseStationFile(bytes);
    return _stationCache[cc] = f;
  }

  /// Country codes that currently have station data, or null if the index cannot be read.
  Future<Set<String>?> stationIndex() async {
    try {
      final r = await client.get(Uri.parse('$dataBase/v1/stations/index.json')).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      final c = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['countries'] as Map?;
      return c?.keys.cast<String>().toSet();
    } catch (_) {
      return null;
    }
  }
}
