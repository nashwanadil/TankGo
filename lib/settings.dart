import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends ChangeNotifier {
  Settings(this._p);
  final SharedPreferences _p;

  String? get lang => _p.getString('lang');
  String? get country => _p.getString('country');
  bool get onboarded => lang != null && country != null;
  bool get noteSeen => _p.getBool('noteSeen') ?? false;
  /// Page opened at every launch: 'home', 'stations' or 'trip'.
  String get startPage => _p.getString('startPage') ?? 'home';
  /// The how-it-works card of the trip planner was closed by the user.
  bool get tripHelpHidden => _p.getBool('tripHelpHidden') ?? false;
  String get fuel => _p.getString('fuel') ?? 'e95';
  ThemeMode get theme => ThemeMode.values.firstWhere((m) => m.name == _p.getString('theme'), orElse: () => ThemeMode.system);

  Future<void> setLang(String v) async {
    await _p.setString('lang', v);
    notifyListeners();
  }

  Future<void> setCountry(String v) async {
    await _p.setString('country', v);
    notifyListeners();
  }

  Future<void> setFuel(String v) async {
    await _p.setString('fuel', v);
    notifyListeners();
  }

  Future<void> setStartPage(String v) async {
    await _p.setString('startPage', v);
    notifyListeners();
  }

  Future<void> setTripHelpHidden(bool v) async {
    await _p.setBool('tripHelpHidden', v);
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode m) async {
    await _p.setString('theme', m.name);
    notifyListeners();
  }

  Future<void> setNoteSeen() async {
    await _p.setBool('noteSeen', true);
  }
}
