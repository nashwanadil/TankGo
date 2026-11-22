import 'package:material_ui/material_ui.dart';

import '../countries.dart';
import '../settings.dart';
import '../strings.dart';
import 'country_sheet.dart';
import 'home.dart' show fuelName, fuelOrder;
import 'brand.dart';
import 'lang_flag.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.settings});
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final c = countryByCode(settings.country);
        return Scaffold(
          appBar: AppBar(title: Text(tr(context, 'settings'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(tx(context, 'defFuel'), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [for (final f in fuelOrder) ButtonSegment(value: f, label: Text(fuelName(context, f)))],
                selected: {settings.fuel},
                onSelectionChanged: (v) => settings.setFuel(v.first),
              ),
              const SizedBox(height: 12),
              Text(tx(context, 'startPage'), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              SegmentedButton<String>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6), textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 13, fontWeight: FontWeight.w700)),
                segments: [
                  ButtonSegment(value: 'home', icon: const Icon(Icons.home_outlined, size: 16), label: FittedBox(fit: BoxFit.scaleDown, child: Text(tx(context, 'startHome'), key: const ValueKey('start_home'), maxLines: 1))),
                  ButtonSegment(value: 'stations', icon: const Icon(Icons.local_gas_station_outlined, size: 16), label: FittedBox(fit: BoxFit.scaleDown, child: Text(tx(context, 'startStations'), key: const ValueKey('start_stations'), maxLines: 1))),
                  ButtonSegment(value: 'trip', icon: const Icon(Icons.map_outlined, size: 16), label: FittedBox(fit: BoxFit.scaleDown, child: Text(tx(context, 'trip'), key: const ValueKey('start_trip'), maxLines: 1))),
                ],
                selected: {settings.startPage},
                onSelectionChanged: (v) => settings.setStartPage(v.first),
              ),
              const SizedBox(height: 12),
              Text(tr(context, 'country'), style: Theme.of(context).textTheme.titleSmall),
              Card(
                child: ListTile(
                  leading: Text(c?.flag ?? '', style: const TextStyle(fontSize: 26)),
                  title: Text(c?.name ?? ''),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final v = await pickCountry(context);
                    if (v != null) settings.setCountry(v);
                  },
                ),
              ),
              const SizedBox(height: 12),
              Text(tr(context, 'theme'), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(value: ThemeMode.system, label: Text(tr(context, 'system'))),
                  ButtonSegment(value: ThemeMode.light, label: Text(tr(context, 'light'))),
                  ButtonSegment(value: ThemeMode.dark, label: Text(tr(context, 'dark'))),
                ],
                selected: {settings.theme},
                onSelectionChanged: (s) => settings.setTheme(s.first),
              ),
              const SizedBox(height: 12),
              Text(tx(context, 'palColor'), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final p in palettes) Expanded(child: _Swatch(p: p, selected: settings.palette == p.id, label: tx(context, 'pal_${p.id}'), onTap: () => settings.setPalette(p.id)))],
              ),
              const SizedBox(height: 12),
              Text(tr(context, 'language'), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 3.4,
                children: [
                  for (final (code, name, flag) in languages.where((l) => !l.$2.startsWith('English (')))
                    _LangTile(code: code, flag: flag, name: name, selected: settings.lang == code, onTap: () => settings.setLang(code)),
                ],
              ),
              const SizedBox(height: 24),
              Text('Data: EU Weekly Oil Bulletin (European Commission), CBS Netherlands (CC BY 4.0), U.S. EIA.', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }
}

class _LangTile extends StatelessWidget {
  const _LangTile({required this.code, required this.flag, required this.name, required this.selected, required this.onTap});
  final String code, flag, name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? cs.primaryContainer : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? cs.primary : Theme.of(context).dividerColor, width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              LangFlag(code: code, flag: flag, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                ),
              ),
              if (selected) Icon(Icons.check, size: 18, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// A colour theme choice: a small hero-like gradient disc with the theme's name.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.p, required this.selected, required this.label, required this.onTap});
  final Palette p;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('pal_${p.id}'),
      borderRadius: BorderRadius.circular(rElement),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [p.light, p.dark]),
                border: Border.all(color: selected ? gold : Colors.transparent, width: 3),
              ),
              child: selected ? const Icon(Icons.check, color: gold, size: 18) : null,
            ),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, maxLines: 2, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
