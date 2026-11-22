// Renders the app screens used in the store screenshots, in every store language, from live data.
// 1. Download data:  see store/screenshots/README.md
// 2. flutter test --update-goldens store/screenshots/app_shots_test.dart
// Output: store/screenshots/src/{lang}/{screen}.png (1080 px wide, like a phone screen without status bar).
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuelprices/app.dart';
import 'package:fuelprices/countries.dart';
import 'package:fuelprices/data.dart';
import 'package:fuelprices/location.dart';
import 'package:fuelprices/premium.dart';
import 'package:fuelprices/settings.dart';
import 'package:fuelprices/ui/compare_page.dart';
import 'package:fuelprices/ui/settings_page.dart';
import 'package:fuelprices/ui/stations_page.dart';
import 'package:fuelprices/ui/trip_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const data = 'store/screenshots/.data';
// Optional: SHOT_PALETTE=emerald SHOT_OUT=preview to look at another colour theme without touching src/.
final palette = Platform.environment['SHOT_PALETTE'] ?? 'burgundy';
final out = Platform.environment['SHOT_OUT'] ?? 'src';
final langs = (Platform.environment['SHOT_LANGS'] ?? 'en,de,ar').split(',');

class _Paris implements LocationSource {
  @override
  Future<LocResult> locate() async => const LocResult(LocStatus.ok, 48.8566, 2.3522);
  @override
  Future<void> openSettings(LocStatus why) async {}
}

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

http.Client _client() => MockClient((r) async {
  final f = File('$data${r.url.path}');
  return f.existsSync() ? http.Response.bytes(f.readAsBytesSync(), 200) : http.Response('{}', 404);
});

void main() {
  setUpAll(() async {
    await _font('NotoSans', [for (final w in [400, 500, 700, 800]) 'assets/fonts/NotoSans-$w.ttf']);
    await _font('NotoKufiArabic', [for (final w in [400, 500, 700, 800]) 'assets/fonts/NotoKufiArabic-$w.ttf']);
    await _font('MaterialIcons', ['${Platform.environment['FLUTTER_ROOT'] ?? '/home/user/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    await _font('NotoColorEmoji', ['/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf']);
    await _font('DejaVuSans', ['/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf']); // symbols such as ▼ (system fonts on a phone)
    extraFontFallback = const ['NotoColorEmoji', 'DejaVuSans'];
  });

  for (final lang in langs) {
    testWidgets('store shots $lang', (t) async {
      t.view.physicalSize = const Size(1080, 2110);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({'lang': lang, 'country': 'DE', 'fuel': 'diesel', 'noteSeen': true, 'tripHelpHidden': true, 'p_life': true, 'palette': palette});
      final prefs = await SharedPreferences.getInstance();
      final settings = Settings(prefs);
      final premium = Premium(prefs, billing: false);
      final api = Api(_client());
      final shot = find.byType(MaterialApp);

      await t.pumpWidget(TankGoApp(settings: settings, api: api, premium: premium));
      await t.pumpAndSettle();

      // Home: two years of history, a past day picked on the chart.
      await t.tap(find.text('2Y'));
      await t.pumpAndSettle();
      final chart = find.byWidgetPredicate((w) => w.runtimeType.toString() == 'LineChart');
      final box = t.getRect(chart);
      // A finger held on the chart: tooltip plus that day's price in the hero (as on the phone).
      final finger = await t.startGesture(Offset(box.left + box.width * (lang == 'ar' ? 0.66 : 0.34), box.top + box.height * 0.5));
      await t.pump();
      await expectLater(shot, matchesGoldenFile('$out/$lang/home.png'));
      await finger.up();
      await t.pumpAndSettle();

      final nav = t.state<NavigatorState>(find.byType(Navigator).first);
      Future<void> open(Widget page, String name, [Future<void> Function()? setup]) async {
        nav.push(MaterialPageRoute<void>(builder: (_) => page));
        await t.pump();
        await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 3))); // isolates (station file parsing)
        await t.pumpAndSettle();
        if (setup != null) await setup();
        await expectLater(shot, matchesGoldenFile('$out/$lang/$name.png'));
        nav.pop();
        await t.pumpAndSettle();
      }

      await open(StationsPage(api: api, settings: settings, fuel: 'diesel', location: _Paris()), 'stations');

      final all = (await api.latest()).value!;
      await open(ComparePage(entries: all, home: 'DE', premium: premium, fuel: 'diesel'), 'compare');

      await open(TripPage(entries: all, home: 'DE', premium: premium, fuel: 'diesel', settings: settings), 'trip', () async {
        await t.enterText(find.byType(TextField).at(2), '490');
        await t.tap(find.byIcon(Icons.add_location_alt_outlined));
        await t.pumpAndSettle();
        await t.tap(find.text(countryByCode('DK')!.name));
        await t.pumpAndSettle();
        final nl = find.text(countryByCode('NL')!.name);
        await t.scrollUntilVisible(nl, 120, scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first);
        await t.ensureVisible(nl);
        await t.pumpAndSettle();
        await t.tap(nl);
        await t.pumpAndSettle();
        await t.enterText(find.byType(TextField).at(3), '600');
        await t.tap(find.byType(Switch));
        FocusManager.instance.primaryFocus?.unfocus();
        await t.pumpAndSettle();
      });

      await open(SettingsPage(settings: settings), 'settings');
    });
  }
}
