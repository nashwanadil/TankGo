import 'package:flutter_test/flutter_test.dart';
import 'package:fuelprices/countries.dart';
import 'package:fuelprices/strings.dart';

void main() {
  test('27 languages, every key translated', () {
    expect(allStrings.length, 27);
    allStrings.forEach((lang, v) {
      expect(v.length, keys.length, reason: lang);
      expect(v.any((s) => s.trim().isEmpty), false, reason: lang);
      expect(v[keys.indexOf('updated')].contains('{d}'), true, reason: lang);
    });
  });

  test('every language entry has strings; every country has a language', () {
    for (final (code, _, _) in languages) {
      expect(allStrings.containsKey(code), true, reason: code);
    }
    expect(countries.length, 28);
    for (final c in countries) {
      expect(allStrings.containsKey(c.lang), true, reason: c.code);
      expect(c.flag.runes.length, 2);
    }
  });

  test('country suggestion', () {
    expect(suggestCountry('de', 'en').code, 'DE');
    expect(suggestCountry(null, 'pl').code, 'PL');
    expect(suggestCountry('XX', 'sv').code, 'SE');
  });
}

