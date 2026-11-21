import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuelprices/app.dart';
import 'package:fuelprices/data.dart';
import 'package:fuelprices/premium.dart';
import 'package:fuelprices/strings.dart';
import 'package:fuelprices/location.dart';
import 'package:fuelprices/settings.dart';
import 'package:fuelprices/ui/stations_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeLoc implements LocationSource {
  FakeLoc(this.results);
  final List<LocResult> results;
  int calls = 0, opened = 0;
  @override
  Future<LocResult> locate() async => results[calls++ < results.length ? calls - 1 : results.length - 1];
  @override
  Future<void> openSettings(LocStatus why) async => opened++;
}

String _d(DateTime d) => d.toIso8601String().substring(0, 10);

http.Client _client(List<Uri> log, {bool fail = false}) => MockClient((r) async {
  log.add(r.url);
  if (fail) return http.Response('x', 500);
  if (r.url.path.endsWith('index.json')) {
    return http.Response(jsonEncode({'updated': 'x', 'countries': {'FR': {}, 'ES': {}, 'IT': {}}}), 200);
  }
  final today = _d(DateTime.now());
  return http.Response(
    jsonEncode({
      'cc': 'FR',
      'updated': '2026-11-21T10:05:00Z',
      'source': 'prix-carburants.gouv.fr',
      's': [
        ['1', 'Total Rivoli', '1 rue de Rivoli', 'Paris', 48.857, 2.352, 1.95, 1.80, null, today],
        ['2', 'Esso Bastille', '2 place Bastille', 'Paris', 48.853, 2.369, 1.85, 1.70, null, '2020-01-01'],
        ['3', 'Leclerc Lointain', 'Route 9', 'Melun', 48.70, 2.50, 1.60, 1.50, null, today],
      ],
    }),
    200,
  );
});

Future<Settings> _settings() async {
  SharedPreferences.setMockInitialValues({'lang': 'de', 'country': 'FR'});
  return Settings(await SharedPreferences.getInstance());
}

Widget _app(Widget home) => MaterialApp(locale: const Locale('de'), supportedLocales: const [Locale('de'), Locale('en')], localizationsDelegates: GlobalMaterialLocalizations.delegates, home: home);

void main() {
  testWidgets('lists nearby stations, cheapest badge, stale date, navigation', (t) async {
    final log = <Uri>[];
    final opened = <Uri>[];
    await t.pumpWidget(
      _app(
        StationsPage(
          api: Api(_client(log)),
          settings: await _settings(),
          location: FakeLoc([const LocResult(LocStatus.ok, 48.8566, 2.3522)]),
          openUrl: (u) async {
            opened.add(u);
            return true;
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    // within 10 km: two Paris stations, not Melun
    expect(find.text('Total Rivoli'), findsOneWidget);
    expect(find.text('Esso Bastille'), findsOneWidget);
    expect(find.text('Leclerc Lointain'), findsNothing);
    expect(find.text('Günstigste'), findsOneWidget);
    // cheapest first (Esso 1.85 < Total 1.95)
    expect(t.getTopLeft(find.text('Esso Bastille')).dy, lessThan(t.getTopLeft(find.text('Total Rivoli')).dy));
    expect(find.textContaining('1,850'), findsOneWidget);
    expect(find.textContaining('Stand 1. Jan.'), findsOneWidget); // only the 2020 row is stale
    expect(find.textContaining('prix-carburants.gouv.fr'), findsOneWidget);
    // privacy: only static file downloads, no coordinates in any URL
    expect(log.every((u) => u.host == Uri.parse(dataBase).host && !u.toString().contains('48.8')), true);
    expect(log.map((u) => u.path), containsAll(['/v1/stations/index.json', '/v1/stations/FR.json']));

    // radius 25 shows Melun; distance sort puts Total (closest) first
    await t.tap(find.byKey(const ValueKey('radius_25')));
    await t.pumpAndSettle();
    expect(find.text('Leclerc Lointain'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('sort_dist')));
    await t.pumpAndSettle();
    expect(t.getTopLeft(find.text('Total Rivoli')).dy, lessThan(t.getTopLeft(find.text('Esso Bastille')).dy));

    // diesel selector
    await t.tap(find.byKey(const ValueKey('fuel_diesel')));
    await t.pumpAndSettle();
    expect(find.textContaining('1,700'), findsOneWidget);

    await t.tap(find.text('Esso Bastille'));
    expect(opened.single.toString(), 'https://www.google.com/maps/dir/?api=1&destination=48.853,2.369');
  });

  testWidgets('outside FR/ES/IT shows not covered message', (t) async {
    final log = <Uri>[];
    await t.pumpWidget(_app(StationsPage(api: Api(_client(log)), settings: await _settings(), location: FakeLoc([const LocResult(LocStatus.ok, 52.52, 13.40)]))));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('stNotCovered')), findsOneWidget);
    expect(find.text('Tankstellenpreise gibt es derzeit für Frankreich, Spanien und Italien. Deutschland folgt.'), findsOneWidget);
    expect(log, isEmpty);
  });

  testWidgets('permission denied explains and retries; blocked offers settings', (t) async {
    final loc = FakeLoc([const LocResult(LocStatus.denied), const LocResult(LocStatus.deniedForever), const LocResult(LocStatus.ok, 48.8566, 2.3522)]);
    await t.pumpWidget(_app(StationsPage(api: Api(_client([])), settings: await _settings(), location: loc)));
    await t.pumpAndSettle();
    expect(find.textContaining('nie gesendet'), findsOneWidget);
    await t.tap(find.text('Standort erlauben'));
    await t.pumpAndSettle();
    expect(find.text('Einstellungen öffnen'), findsOneWidget);
    await t.tap(find.text('Einstellungen öffnen'));
    expect(loc.opened, 1);
    await t.tap(find.text('Erneut versuchen'));
    await t.pumpAndSettle();
    expect(find.text('Total Rivoli'), findsOneWidget);
  });

  testWidgets('download error shows retry', (t) async {
    await t.pumpWidget(_app(StationsPage(api: Api(_client([], fail: true)), settings: await _settings(), location: FakeLoc([const LocResult(LocStatus.ok, 48.8566, 2.3522)]))));
    await t.pumpAndSettle();
    expect(find.textContaining('konnten nicht geladen werden'), findsOneWidget);
  });

  test('station strings exist in en, de and ar', () {
    for (final k in ['stNear', 'stCovered', 'stNotCovered', 'stPermBody', 'stAllow', 'stSettings', 'stErr', 'stCheapest', 'stAsOf', 'stSource', 'stRadius', 'stSortPrice', 'stSortDist', 'stNone', 'stNote']) {
      expect(txLang('de', k), isNot(txLang('en', k)), reason: 'de $k');
      expect(txLang('ar', k), isNot(txLang('en', k)), reason: 'ar $k');
    }
  });

  testWidgets('home shows the free stations card, tap opens the page', (t) async {
    SharedPreferences.setMockInitialValues({'lang': 'de', 'country': 'FR', 'noteSeen': true});
    final latest = jsonEncode({
      'countries': {
        'FR': {'date': '2026-11-16', 'prices': {'e95': 1.9, 'diesel': 1.8, 'lpg': 0.9}, 'prev': null, 'currency': 'EUR', 'unit': 'L', 'frequency': 'daily', 'source': 'EU'},
      },
    });
    final api = Api(MockClient((r) async => http.Response(r.url.path.contains('history') ? '{}' : latest, 200)));
    final prefs = await SharedPreferences.getInstance();
    await t.pumpWidget(TankGoApp(settings: Settings(prefs), api: api, premium: Premium(prefs, billing: false)));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('stNear')), findsOneWidget);
    expect(find.text('Günstige Tankstellen in der Nähe'), findsOneWidget);
    await t.ensureVisible(find.byKey(const ValueKey('stNear')));
    await t.tap(find.text('Günstige Tankstellen in der Nähe'));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(StationsPage, skipOffstage: false), findsOneWidget);
    await t.pumpWidget(const SizedBox()); // dispose before the (unmocked) location plugin call settles
  });
}
