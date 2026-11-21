import 'package:material_ui/material_ui.dart';
import '../countries.dart';
import '../data.dart';
import '../premium.dart';
import '../strings.dart';
import '../trip.dart';
import 'fmt.dart';
import 'home.dart' show fuelColor, fuelName, fuelOrder;
import 'paywall.dart';

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
  final _l = TextEditingController(text: '50');

  @override
  void dispose() {
    _l.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final eu = widget.entries.entries.where((e) => e.value.currency == 'EUR').toList();
    final fuels = fuelOrder.where((f) => eu.any((e) => e.value.prices.containsKey(f))).toList();
    if (!fuels.contains(_fuel)) _fuel = fuels.first;
    final rows = [for (final e in eu) if (e.value.prices.containsKey(_fuel)) (e.key, e.value.prices[_fuel]!)]..sort((a, b) => a.$2.compareTo(b.$2));
    final homePrice = rows.where((r) => r.$1 == widget.home).map((r) => r.$2).firstOrNull;
    final liters = double.tryParse(_l.text.replaceAll(',', '.')) ?? 0;
    final near = neighbours[widget.home] ?? const <String>[];
    final freeSet = {widget.home, ...(near.isEmpty ? rows.take(3).map((r) => r.$1) : near)};
    final premium = widget.premium;
    return ListenableBuilder(
      listenable: premium,
      builder: (context, _) {
        final full = premium.isPremium;
        final shown = full ? rows : rows.where((r) => freeSet.contains(r.$1)).toList();
        return Scaffold(
          appBar: AppBar(title: Text(tx(context, 'compare'))),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Wrap(spacing: 8, children: [
              for (final f in fuels)
                ChoiceChip(
                  label: Text(fuelName(context, f)),
                  selected: _fuel == f,
                  selectedColor: fuelColor(context, f).withValues(alpha: 0.3),
                  onSelected: (_) => setState(() => _fuel = f),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _l,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: tx(context, 'cmpLiters'), border: const OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            for (final r in shown)
              Builder(builder: (context) {
                final c = countryByCode(r.$1)!;
                final isHome = r.$1 == widget.home;
                final diff = homePrice == null ? null : (homePrice - r.$2) * liters;
                final cheapest = rows.first.$1 == r.$1;
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isHome ? fuelColor(context, _fuel) : Theme.of(context).dividerColor.withValues(alpha: 0.4), width: isHome ? 2 : 1),
                  ),
                  child: ListTile(
                    leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                    title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(isHome ? tx(context, 'yourCountry') : (diff == null ? '' : '${tx(context, 'cmpSave')}: ${diff >= 0 ? '+' : ''}${fmtMoney(diff, 'EUR', lang, 2)}'),
                        style: TextStyle(color: isHome || diff == null ? null : (diff >= 0 ? const Color(0xFF2E8B6A) : Theme.of(context).colorScheme.error), fontWeight: FontWeight.w600)),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(fmtMoney(r.$2, 'EUR', lang), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      if (cheapest) const Icon(Icons.arrow_downward, size: 14, color: Color(0xFF2E8B6A)),
                    ]),
                  ),
                );
              }),
            if (!full && rows.length > shown.length)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.lock, color: Color(0xFFE0B860)),
                  title: Text(tx(context, 'cmpMore')),
                  trailing: Text(tx(context, 'unlock'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  onTap: () => showPaywall(context, premium),
                ),
              ),
          ]),
        );
      },
    );
  }
}
