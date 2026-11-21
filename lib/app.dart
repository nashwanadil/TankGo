import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoLocalizations, GlobalCupertinoLocalizations;
import 'package:material_ui/material_ui.dart';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter_localizations/flutter_localizations.dart' hide GlobalMaterialLocalizations, GlobalCupertinoLocalizations;
import 'data.dart';
import 'settings.dart';
import 'strings.dart';
import 'ui/home.dart';
import 'ui/onboarding.dart';

/// Falls back to English for locales Flutter's own widgets do not translate (e.g. Maltese).
class _Fb<T> extends LocalizationsDelegate<T> {
  const _Fb(this.inner);
  final LocalizationsDelegate<T> inner;
  @override
  bool isSupported(Locale l) => true;
  @override
  Future<T> load(Locale l) => inner.load(inner.isSupported(l) ? l : const Locale('en'));
  @override
  bool shouldReload(covariant _Fb<T> old) => false;
}

ThemeData _theme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFFF59E0B), brightness: b);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: b == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFF4F6FA),
    cardTheme: CardThemeData(
      elevation: 0,
      color: b == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

class TankGoApp extends StatelessWidget {
  const TankGoApp({super.key, required this.settings, required this.api});
  final Settings settings;
  final Api api;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final dev = PlatformDispatcher.instance.locale.languageCode;
        final lang = settings.lang ?? (supportedLangs.contains(dev) ? dev : 'en');
        return MaterialApp(
          title: 'TankGo',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: settings.theme,
          locale: Locale(lang),
          supportedLocales: [for (final l in supportedLangs) Locale(l)],
          localizationsDelegates: const [
            _Fb<MaterialLocalizations>(GlobalMaterialLocalizations.delegate),
            _Fb<WidgetsLocalizations>(GlobalWidgetsLocalizations.delegate),
            _Fb<CupertinoLocalizations>(GlobalCupertinoLocalizations.delegate),
          ],
          home: settings.onboarded ? HomePage(settings: settings, api: api) : OnboardingPage(settings: settings),
        );
      },
    );
  }
}
