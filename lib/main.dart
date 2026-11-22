import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data.dart';
import 'premium.dart';
import 'settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  final prefs = await SharedPreferences.getInstance();
  final settings = Settings(prefs);
  final premium = Premium(prefs)..start();
  final api = Api();
  api.config().then((c) {
    final v = c.value;
    if (v != null) premium.setRemoteFree(v['premiumFree'] == true);
  });
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(TankGoApp(settings: settings, api: api, premium: premium));
}
