import 'package:material_ui/material_ui.dart';

import '../countries.dart';
import '../settings.dart';
import '../strings.dart';
import 'country_sheet.dart';

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
              Text(tr(context, 'language'), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 3.4,
                children: [
                  for (final (code, name, flag) in languages.where((l) => !l.$2.startsWith('English (')))
                    _LangTile(flag: flag, name: name, selected: settings.lang == code, onTap: () => settings.setLang(code)),
                ],
              ),
              const SizedBox(height: 20),
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
              const SizedBox(height: 20),
              Text(tr(context, 'theme'), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(value: ThemeMode.system, label: Text(tr(context, 'system'))),
                  ButtonSegment(value: ThemeMode.light, label: Text(tr(context, 'light'))),
                  ButtonSegment(value: ThemeMode.dark, label: Text(tr(context, 'dark'))),
                ],
                selected: {settings.theme},
                onSelectionChanged: (s) => settings.setTheme(s.first),
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
  const _LangTile({required this.flag, required this.name, required this.selected, required this.onTap});
  final String flag, name;
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
              Text(flag, style: const TextStyle(fontSize: 20)),
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
