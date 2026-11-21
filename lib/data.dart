import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const dataBase = String.fromEnvironment('DATA_BASE', defaultValue: 'https://nashwanadil.github.io/fuelprices');
const galToL = 3.78541;

class Entry {
  final DateTime date;
  final Map<String, double> prices;
  final Map<String, double>? prev;
  final String currency, unit, frequency, source;
  Entry(this.date, this.prices, this.prev, this.currency, this.unit, this.frequency, this.source);

  static Map<String, double> _m(Map v) => {for (final e in v.entries) e.key as String: (e.value as num).toDouble()};

  factory Entry.fromJson(Map j) => Entry(DateTime.parse(j['date']), _m(j['prices']),
      j['prev'] == null ? null : _m(j['prev']), j['currency'], j['unit'], j['frequency'], j['source']);

  /// Price per litre (converts US gallon prices).
  double perLitre(double v) => unit == 'gal' ? v / galToL : v;
}

class Series {
  final String currency, unit;
  final List<(DateTime, double)> points;
  Series(this.currency, this.unit, this.points);
}

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

  Future<Loaded<Map<String, Entry>>> latest() async {
    final r = await _get('v1/latest.json', 'latest');
    final c = r.value?['countries'] as Map?;
    if (c == null) return Loaded(null, true);
    return Loaded({for (final e in c.entries) e.key as String: Entry.fromJson(e.value as Map)}, r.offline);
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
    return {
      for (final e in out.entries) e.key: Series(j['currency'], j['unit'], e.value..sort((a, b) => a.$1.compareTo(b.$1)))
    };
  }
}
