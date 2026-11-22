import 'package:flutter_test/flutter_test.dart';
import 'package:fuelprices/app.dart';
import 'package:fuelprices/settings.dart';
import 'package:fuelprices/ui/brand.dart';
import 'package:fuelprices/ui/settings_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => pal = palettes.first);

  test('palette drives primary colours; dark mode is near-black, light mode milky', () {
    pal = paletteById('emerald');
    expect(appTheme(Brightness.light).colorScheme.primary, const Color(0xFF1F7A5A));
    expect(appTheme(Brightness.dark).scaffoldBackgroundColor, bgDark);
    expect(appTheme(Brightness.light).scaffoldBackgroundColor, ivory);
    expect(paletteById('nope').id, 'burgundy');
  });

  testWidgets('settings: picking a colour saves it', (t) async {
    SharedPreferences.setMockInitialValues({'lang': 'en', 'country': 'DE'});
    final st = Settings(await SharedPreferences.getInstance());
    await t.pumpWidget(MaterialApp(home: SettingsPage(settings: st)));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.byKey(const ValueKey('pal_night')), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.byKey(const ValueKey('pal_night')));
    await t.pumpAndSettle();
    expect(st.palette, 'night');
    expect(find.text('Night blue'), findsOneWidget);
  });
}
