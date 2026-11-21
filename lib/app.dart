import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoLocalizations, GlobalCupertinoLocalizations;
import 'package:material_ui/material_ui.dart';

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_localizations/flutter_localizations.dart' hide GlobalMaterialLocalizations, GlobalCupertinoLocalizations;

import 'data.dart';
import 'premium.dart';
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
    onPrimary: dark ? darkBrown : Colors.white,
    primaryContainer: dark ? primaryContainerDark : primaryContainerLight,
    onPrimaryContainer: dark ? cream : brandDeep,
    surface: dark ? darkBrown : ivory,
    surfaceContainerHighest: dark ? surfaceHighDark : surfaceHighLight,
    onSurface: dark ? cream : darkBrown,
    error: dark ? errorDark : errorLight,
    errorContainer: dark ? errorContainerDark : errorContainerLight,
  );
  return ThemeData(
    fontFamily: 'NotoSans',
    fontFamilyFallback: const ['NotoKufiArabic'],
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      iconTheme: IconThemeData(color: dark ? gold : brand),
      actionsIconTheme: IconThemeData(color: dark ? gold : brand),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: dark ? cardDark : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: dark ? borderDark : borderLight),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: dark ? cardDark : Colors.white,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: dark ? brandDark : brand,
      headerForegroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      todayBorder: const BorderSide(color: gold, width: 1.5),
      todayForegroundColor: WidgetStatePropertyAll(dark ? gold : brand),
    ),
    chipTheme: ChipThemeData(
      selectedColor: scheme.primaryContainer,
      side: BorderSide(color: dark ? borderDark : chipBorderLight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

class TankGoApp extends StatelessWidget {
  const TankGoApp({super.key, required this.settings, required this.api, required this.premium});
  final Settings settings;
  final Api api;
  final Premium premium;

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
          builder: (c, child) => Directionality(textDirection: const {'ar', 'fa', 'ku'}.contains(lang) ? TextDirection.rtl : TextDirection.ltr, child: child!),
          home: settings.onboarded ? HomePage(settings: settings, api: api, premium: premium) : OnboardingPage(settings: settings),
        );
      },
    );
  }
}
