import 'dart:convert';
import 'package:material_ui/material_ui.dart' show TextField, Icons, DatePickerDialog;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuelprices/app.dart';
import 'package:fuelprices/data.dart';
import 'package:fuelprices/premium.dart';
import 'package:fuelprices/settings.dart';

final _latest = jsonEncode({
  'countries': {
    'NL': {'date': '2026-11-16', 'prices': {'e95': 2.151, 'diesel': 2.294, 'lpg': 1.028}, 'prev': {'e95': 2.148, 'diesel': 2.29, 'lpg': 1.011}, 'currency': 'EUR', 'unit': 'L', 'frequency': 'daily', 'source': 'CBS'},
    'US': {'date': '2026-11-16', 'prices': {'e95': 3.0, 'diesel': 3.8}, 'prev': null, 'currency': 'USD', 'unit': 'gal', 'frequency': 'weekly', 'source': 'EIA'},
  }
});
final _hist = jsonEncode({
  'currency': 'EUR', 'unit': 'L',
  'points': {for (var i = 0; i < 30; i++) '2026-10-${(i + 1).toString().padLeft(2, '0')}': {'e95': 2.0 + i / 100}}
});

void main() {
  testWidgets('first run: language -> country -> note -> prices', (t) async {
    SharedPreferences.setMockInitialValues({});
    final api = Api(MockClient((r) async => http.Response(r.url.path.contains('history') ? _hist : _latest, 200)));
    final s = Settings(await SharedPreferences.getInstance());
    await t.pumpWidget(TankGoApp(settings: s, api: api, premium: Premium(await SharedPreferences.getInstance(), billing: false)));
    await t.pumpAndSettle();
    expect(find.text('Deutsch'), findsOneWidget);
    await t.ensureVisible(find.text('Deutsch'));
    await t.tap(find.text('Deutsch'));
    await t.pumpAndSettle();
    expect(find.text('Land wählen'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Neder');
    await t.pumpAndSettle();
    await t.tap(find.text('Nederland'));
    await t.pumpAndSettle();
    expect(find.text('Hinweis'), findsOneWidget);
    await t.tap(find.text('Verstanden'));
    await t.pumpAndSettle();
    expect(find.textContaining('2,151'), findsWidgets);
    expect(find.textContaining('CBS'), findsOneWidget);
    expect(s.noteSeen, true);
    expect(s.country, 'NL');
  });

  testWidgets('returning user skips onboarding and note', (t) async {
    SharedPreferences.setMockInitialValues({'lang': 'en', 'country': 'US', 'noteSeen': true});
    final api = Api(MockClient((r) async => http.Response(r.url.path.contains('history') ? _hist : _latest, 200)));
    final s = Settings(await SharedPreferences.getInstance());
    await t.pumpWidget(TankGoApp(settings: s, api: api, premium: Premium(await SharedPreferences.getInstance(), billing: false)));
    await t.pumpAndSettle();
    expect(find.text('Please note'), findsNothing);
    expect(find.textContaining('\$3.000 /gal'), findsOneWidget);
  });

  testWidgets('calendar: pick a past date shows its price', (t) async {
    SharedPreferences.setMockInitialValues({'lang': 'en', 'country': 'US', 'noteSeen': true, 'p_life': true});
    final api = Api(MockClient((r) async => http.Response(r.url.path.contains('history') ? _hist : _latest, 200)));
    final s = Settings(await SharedPreferences.getInstance());
    await t.pumpWidget(TankGoApp(settings: s, api: api, premium: Premium(await SharedPreferences.getInstance(), billing: false)));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.event));
    await t.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await t.tap(find.text('15'));
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(find.textContaining('\$2.140 /gal'), findsOneWidget);
    await t.tap(find.text('Latest'));
    await t.pumpAndSettle();
    expect(find.textContaining('\$3.000 /gal'), findsOneWidget);
  });

  testWidgets('calendar: free user is sent to the paywall for dates older than 30 days', (t) async {
    SharedPreferences.setMockInitialValues({'lang': 'en', 'country': 'US', 'noteSeen': true});
    final api = Api(MockClient((r) async => http.Response(r.url.path.contains('history') ? _hist : _latest, 200)));
    final s = Settings(await SharedPreferences.getInstance());
    await t.pumpWidget(TankGoApp(settings: s, api: api, premium: Premium(await SharedPreferences.getInstance(), billing: false)));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.event));
    await t.pumpAndSettle();
    await t.tap(find.text('15'));
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(find.text('Unlock TankGo Premium'), findsOneWidget);
    expect(find.textContaining('\$2.140 /gal'), findsNothing);
  });

  test('gallon conversion', () {
    final e = Entry(DateTime(2026), {'e95': 3.785}, null, 'USD', 'gal', 'weekly', 'EIA');
    expect(e.perLitre(3.78541), closeTo(1.0, 1e-6));
  });
}
