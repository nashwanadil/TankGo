import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuelprices/data.dart';
import 'package:fuelprices/premium.dart';
import 'package:fuelprices/ui/compare_page.dart';
import 'package:fuelprices/ui/trip_page.dart';

Entry _e(double p) => Entry(DateTime(2026, 11, 16), {'e95': p}, null, 'EUR', 'L', 'weekly', 'WOB');
final _all = {'DE': _e(1.9), 'FR': _e(1.85), 'PL': _e(1.45), 'LU': _e(1.55), 'AT': _e(1.6), 'SI': _e(1.5), 'HR': _e(1.45), 'IT': _e(1.95)};

Future<Premium> _p(bool paid) async {
  SharedPreferences.setMockInitialValues(paid ? {'p_life': true} : {});
  return Premium(await SharedPreferences.getInstance(), billing: false);
}

void main() {
  testWidgets('free compare: popular neighbours locked, less-visited open', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: ComparePage(entries: _all, home: 'DE', premium: await _p(false)),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('1,450'), findsNothing); // locale en -> '1.450'
    expect(find.textContaining('1.450'), findsOneWidget); // PL open
    expect(find.textContaining('1.550'), findsOneWidget); // LU open
    expect(find.textContaining('1.850'), findsNothing); // FR locked
    expect(find.textContaining('1.600'), findsNothing); // AT locked
    expect(find.byIcon(Icons.lock), findsWidgets);
  });

  testWidgets('free trip planner shows the demo route with a result', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: TripPage(entries: _all, home: 'DE', premium: await _p(false)),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Example route – unlock to plan your own trips'), findsOneWidget);
    expect(find.text('Fuel total'), findsOneWidget);
    expect(find.textContaining('Vignettes'), findsOneWidget);
  });

  testWidgets('trip help card: close mark hides it, info icon reopens it as a dialog', (t) async {
    await t.pumpWidget(MaterialApp(home: TripPage(entries: _all, home: 'DE', premium: await _p(false))));
    await t.pumpAndSettle();
    expect(find.textContaining('How it works:'), findsOneWidget);
    expect(find.byKey(const ValueKey('tripHelp')), findsNothing);
    await t.tap(find.byKey(const ValueKey('tripHelpClose')));
    await t.pumpAndSettle();
    expect(find.textContaining('How it works:'), findsNothing);
    await t.tap(find.byKey(const ValueKey('tripHelp')));
    await t.pumpAndSettle();
    expect(find.textContaining('How it works:'), findsOneWidget);
    await t.tap(find.text('Got it'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('tripHelp'))); // can be opened again and again
    await t.pumpAndSettle();
    expect(find.textContaining('How it works:'), findsOneWidget);
  });
}
