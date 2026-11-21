import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoLocalizations, GlobalCupertinoLocalizations;
import 'package:material_ui/material_ui.dart';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter_localizations/flutter_localizations.dart' hide GlobalMaterialLocalizations, GlobalCupertinoLocalizations;
import 'data.dart';
import 'settings.dart';
import 'strings.dart';
import 'ui/brand.dart';
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
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: brand, brightness: b).copyWith(
    primary: dark ? gold : brand,
    onPrimary: dark ? const Color(0xFF2A1D17) : Colors.white,
    primaryContainer: dark ? const Color(0xFF4A3226) : const Color(0xFFF3D9DC),
    onPrimaryContainer: dark ? const Color(0xFFF5ECE0) : const Color(0xFF3B0C15),
    surface: dark ? const Color(0xFF2A1D17) : const Color(0xFFF5F1F0),
    surfaceContainerHighest: dark ? const Color(0xFF43312A) : const Color(0xFFEADFDB),
    onSurface: dark ? const Color(0xFFF5ECE0) : const Color(0xFF2A1D17),
    error: dark ? const Color(0xFFFF8A80) : const Color(0xFFB3261E),
    errorContainer: dark ? const Color(0xFF5A2A2A) : const Color(0xFFF9DEDC),
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: dark ? const Color(0xFF362720) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: dark ? const Color(0xFF4F3B2F) : const Color(0xFFE8DCD6)),
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: scheme.primaryContainer,
      side: BorderSide(color: dark ? const Color(0xFF4F3B2F) : const Color(0xFFE0D2CC)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
