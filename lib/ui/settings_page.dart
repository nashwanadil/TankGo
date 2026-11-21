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
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Text(tr(context, 'language'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (code, name, flag) in languages.where((l) => !l.$2.startsWith('English (')))
                ChoiceChip(
                  label: Text('$flag $name'),
                  selected: settings.lang == code,
                  onSelected: (_) => settings.setLang(code),
                ),
            ]),
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
            Text('Data: EU Weekly Oil Bulletin (European Commission), CBS Netherlands (CC BY 4.0), U.S. EIA.',
                style: Theme.of(context).textTheme.bodySmall),
          ]),
        );
      },
    );
  }
}
