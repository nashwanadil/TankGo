import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends ChangeNotifier {
  Settings(this._p);
  final SharedPreferences _p;

  String? get lang => _p.getString('lang');
  String? get country => _p.getString('country');
  bool get onboarded => lang != null && country != null;
  bool get noteSeen => _p.getBool('noteSeen') ?? false;
  ThemeMode get theme => ThemeMode.values.firstWhere((m) => m.name == _p.getString('theme'), orElse: () => ThemeMode.system);

  Future<void> setLang(String v) async {
    await _p.setString('lang', v);
    notifyListeners();
  }

  Future<void> setCountry(String v) async {
    await _p.setString('country', v);
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
