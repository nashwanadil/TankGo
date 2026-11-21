import 'package:material_ui/material_ui.dart';

import '../countries.dart';
import '../data.dart';
import '../premium.dart';
import '../strings.dart';
import '../trip.dart';
import 'brand.dart';
import 'fmt.dart';
import 'number_row.dart';
import 'home.dart' show fuelColor, fuelName, fuelOrder;
import 'paywall.dart';

/// Country-vs-neighbours list. [all] shows every EU country (Premium page).
class CompareList extends StatefulWidget {
  const CompareList({super.key, required this.entries, required this.home, required this.premium, required this.fuel, this.all = false, this.onShowAll});
  final Map<String, Entry> entries;
  final String home;
  final Premium premium;
  final String fuel;
  final bool all;
  final VoidCallback? onShowAll;
  @override
  State<CompareList> createState() => _CompareListState();
}

class _CompareListState extends State<CompareList> {
  final _l = TextEditingController(text: '50');

  @override
  void dispose() {
    _l.dispose();
    super.dispose();
  }

  ShapeBorder _shape(BuildContext c, {Color? accent}) => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(rCard),
    side: BorderSide(color: accent ?? Theme.of(c).dividerColor.withValues(alpha: 0.4), width: accent != null ? 2 : 1),
  );

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final fuel = widget.fuel;
    final eu = widget.entries.entries.where((e) => e.value.currency == 'EUR');
    final rows = [
      for (final e in eu)
        if (e.value.prices.containsKey(fuel)) (e.key, e.value.prices[fuel]!),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    if (rows.isEmpty) return const SizedBox();
    final homePrice = rows.where((r) => r.$1 == widget.home).map((r) => r.$2).firstOrNull;
    final liters = double.tryParse(_l.text.replaceAll(',', '.')) ?? 0;
    final near = neighbours[widget.home] ?? const <String>[];
    final nearSet = {widget.home, ...(near.isEmpty ? rows.take(4).map((r) => r.$1) : near)};
    return ListenableBuilder(
      listenable: widget.premium,
      builder: (context, _) {
        final full = widget.premium.isPremium;
        final showAll = widget.all && full;
        final shown = showAll ? rows : rows.where((r) => nearSet.contains(r.$1)).toList();
        bool locked(String cc) => !full && cc != widget.home && premiumCountries.contains(cc);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NumberRow(icon: Icons.local_gas_station, label: tx(context, 'cmpLiters'), controller: _l, suffix: ' L', color: gold, onChanged: (_) => setState(() {})),
            for (final r in shown)
              Builder(
                builder: (context) {
                  final c = countryByCode(r.$1)!;
                  final isHome = r.$1 == widget.home;
                  if (locked(r.$1)) {
                    return Card(
                      shape: _shape(context),
                      child: ListTile(
                        leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                        title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(tx(context, 'premium')),
                        trailing: const Icon(Icons.lock, color: gold),
                        onTap: () => showPaywall(context, widget.premium),
                      ),
                    );
                  }
                  final diff = homePrice == null ? null : (homePrice - r.$2) * liters;
                  return Card(
                    shape: _shape(context, accent: isHome ? fuelColor(context, fuel) : null),
                    child: ListTile(
                      leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                      title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        isHome ? tx(context, 'yourCountry') : (diff == null ? '' : '${tx(context, 'cmpSave')}: ${diff >= 0 ? '+' : ''}${fmtMoney(diff, 'EUR', lang, 2)}'),
                        style: TextStyle(color: isHome || diff == null ? null : (diff >= 0 ? positive : Theme.of(context).colorScheme.error), fontWeight: FontWeight.w600),
                      ),
                      trailing: Text(fmtMoney(r.$2, 'EUR', lang), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    ),
                  );
                },
              ),
            if (!showAll)
              Card(
                shape: _shape(context),
                child: ListTile(
                  leading: Icon(full ? Icons.public : Icons.lock, color: gold),
                  title: Text(tx(context, full ? 'cmpAll' : 'cmpMore')),
                  trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface),
                  onTap: full ? widget.onShowAll : () => showPaywall(context, widget.premium),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Full comparison of all EU countries (Premium).
class ComparePage extends StatefulWidget {
  const ComparePage({super.key, required this.entries, required this.home, required this.premium, this.fuel = 'e95'});
  final Map<String, Entry> entries;
  final String home;
  final Premium premium;
  final String fuel;
  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  late String _fuel = widget.fuel;

  @override
  Widget build(BuildContext context) {
    final eu = widget.entries.values.where((e) => e.currency == 'EUR');
    final fuels = fuelOrder.where((f) => eu.any((e) => e.prices.containsKey(f))).toList();
    if (!fuels.contains(_fuel)) _fuel = fuels.first;
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'compare'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final f in fuels)
                ChoiceChip(label: Text(fuelName(context, f)), selected: _fuel == f, selectedColor: fuelColor(context, f).withValues(alpha: 0.3), onSelected: (_) => setState(() => _fuel = f)),
            ],
          ),
          const SizedBox(height: 12),
          CompareList(entries: widget.entries, home: widget.home, premium: widget.premium, fuel: _fuel, all: true),
        ],
      ),
    );
  }
}
