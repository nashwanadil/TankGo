import 'dart:ui' show PlatformDispatcher;

import 'package:material_ui/material_ui.dart';

import '../countries.dart';
import '../settings.dart';
import '../strings.dart';
import 'lang_flag.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.settings});
  final Settings settings;
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  bool _langDone = false;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 24, 16, 0), child: _langDone ? _countryStep(context) : _langStep(context)),
      ),
    );
  }

  Widget _head(BuildContext c, String key) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(Icons.local_gas_station, color: Theme.of(c).colorScheme.primary, size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Text(tr(c, key), style: Theme.of(c).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  Widget _langStep(BuildContext c) => Column(
    children: [
      _head(c, 'pickLang'),
      Expanded(
        child: ListView(
          children: [
            for (final (code, name, flag) in languages)
              Card(
                child: ListTile(
                  leading: LangFlag(code: code, flag: flag, size: 28),
                  title: Text(name),
                  onTap: () async {
                    await widget.settings.setLang(code);
                    if (mounted) setState(() => _langDone = true);
                  },
                ),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _countryStep(BuildContext c) {
    final lang = widget.settings.lang ?? 'en';
    final sug = suggestCountry(PlatformDispatcher.instance.locale.countryCode, lang);
    final list = countries.where((x) => x.name.toLowerCase().contains(_q.toLowerCase())).toList();
    return Column(
      children: [
        _head(c, 'pickCountry'),
        TextField(
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: tr(c, 'search'), border: const OutlineInputBorder()),
          onChanged: (v) => setState(() => _q = v),
        ),
        const SizedBox(height: 8),
        Expanded(child: ListView(children: [if (_q.isEmpty) _tile(sug, highlight: true), for (final x in list.where((x) => _q.isNotEmpty || x.code != sug.code)) _tile(x)])),
      ],
    );
  }

  Widget _tile(Country x, {bool highlight = false}) => Card(
    color: highlight ? Theme.of(context).colorScheme.primaryContainer : null,
    child: ListTile(
      leading: Text(x.flag, style: const TextStyle(fontSize: 28)),
      title: Text(x.name),
      onTap: () => widget.settings.setCountry(x.code),
    ),
  );
}
