import 'package:material_ui/material_ui.dart';

import '../countries.dart';
import '../data.dart';
import '../premium.dart';
import '../strings.dart';
import '../trip.dart';
import 'fmt.dart';
import 'number_row.dart';
import 'home.dart' show fuelName, fuelOrder;
import 'paywall.dart';

class TripPage extends StatefulWidget {
  const TripPage({super.key, required this.entries, required this.home, required this.premium});
  final Map<String, Entry> entries;
  final String home;
  final Premium premium;
  @override
  State<TripPage> createState() => _TripPageState();
}

class _LegRow {
  _LegRow(this.cc, String km) : km = TextEditingController(text: km);
  String cc;
  final TextEditingController km;
}

class _TripPageState extends State<TripPage> {
  final _tank = TextEditingController(text: '50');
  final _cons = TextEditingController(text: '6.5');
  late final List<_LegRow> _legs = [_LegRow(widget.home == 'US' ? 'DE' : widget.home, '200')];
  String _fuel = 'e95';
  bool _full = true;

  List<Country> get _eu => countries.where((c) => widget.entries[c.code]?.currency == 'EUR').toList();

  double _n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  @override
  void dispose() {
    _tank.dispose();
    _cons.dispose();
    for (final l in _legs) {
      l.km.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return ListenableBuilder(
      listenable: widget.premium,
      builder: (context, _) {
        final t = Theme.of(context);
        final demo = !widget.premium.isPremium;
        final prices = {
          for (final c in _eu)
            if (widget.entries[c.code]!.prices[_fuel] != null) c.code: widget.entries[c.code]!.prices[_fuel]!,
        };
        final legs = demo ? demoRoute : [for (final l in _legs) Leg(l.cc, _n(l.km))];
        final plan = planTrip(legs, prices, tank: demo ? 50 : _n(_tank), consumption: demo ? 6.5 : _n(_cons), startFull: demo || _full);
        final vig = legs.where((l) => l.km > 0).map((l) => l.cc).toSet().fold(0.0, (a, cc) => a + (vignetteEur[cc] ?? 0));
        final fuels = fuelOrder.where((f) => _eu.any((c) => widget.entries[c.code]!.prices.containsKey(f))).toList();
        return Scaffold(
          appBar: AppBar(title: Text(tx(context, 'trip'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: t.colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(child: Text(tx(context, 'tripHow'))),
                    ],
                  ),
                ),
              ),
              if (demo)
                Card(
                  color: const Color(0xFF6B1A2E),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.workspace_premium, color: Color(0xFFE0B860)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tx(context, 'tripDemo'),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE0B860), foregroundColor: const Color(0xFF2A1D17)),
                          onPressed: () => showPaywall(context, widget.premium),
                          child: Text(tx(context, 'unlock')),
                        ),
                      ],
                    ),
                  ),
                ),
              if (demo)
                for (final l in demoRoute)
                  ListTile(
                    dense: true,
                    leading: Text(countryByCode(l.cc)!.flag, style: const TextStyle(fontSize: 22)),
                    title: Text(countryByCode(l.cc)!.name),
                    trailing: Text('${fmtNum(l.km, lang, 0)} km'),
                  ),
              if (!demo) ...[
                Wrap(
                  spacing: 8,
                  children: [for (final f in fuels) ChoiceChip(label: Text(fuelName(context, f)), selected: _fuel == f, onSelected: (_) => setState(() => _fuel = f))],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tank,
                        onTap: () => selectAll(_tank),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: tx(context, 'tripTank'), border: const OutlineInputBorder()),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _cons,
                        onTap: () => selectAll(_cons),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: tx(context, 'tripCons'), border: const OutlineInputBorder()),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(tx(context, 'tripFull')), value: _full, onChanged: (v) => setState(() => _full = v)),
                if (_legs.isEmpty) Text(tx(context, 'tripEmpty')),
                for (final (i, l) in _legs.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: _eu.any((c) => c.code == l.cc) ? l.cc : null,
                            isExpanded: true,
                            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                            items: [
                              for (final c in _eu)
                                DropdownMenuItem(
                                  value: c.code,
                                  child: Text('${c.flag} ${c.name}', overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            onChanged: (v) => setState(() => l.cc = v ?? l.cc),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: l.km,
                            onTap: () => selectAll(l.km),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(suffixText: 'km', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _legs.removeAt(i).km.dispose())),
                      ],
                    ),
                  ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(icon: const Icon(Icons.add), label: Text(tx(context, 'tripAdd')), onPressed: () => setState(() => _legs.add(_LegRow(_eu.first.code, '200')))),
                ),
              ],
              const SizedBox(height: 8),
              if (plan != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final s in plan.stops)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Text(countryByCode(s.cc)!.flag, style: const TextStyle(fontSize: 22)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(tx(context, 'tripBuy').replaceFirst('{l}', fmtNum(s.litres, lang, 0)))),
                                Text('${fmtMoney(s.price, 'EUR', lang)}/L', style: t.textTheme.bodySmall),
                                const SizedBox(width: 10),
                                Text(fmtMoney(s.cost, 'EUR', lang, 2), style: const TextStyle(fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        const Divider(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(tx(context, 'tripTotal'), style: const TextStyle(fontWeight: FontWeight.w800)),
                            ),
                            Text(fmtMoney(plan.total, 'EUR', lang, 2), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                          ],
                        ),
                        if (plan.saved > 0.005)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${tx(context, 'tripSaved')}: ${fmtMoney(plan.saved, 'EUR', lang, 2)}',
                              style: const TextStyle(color: Color(0xFF2E8B6A), fontWeight: FontWeight.w600),
                            ),
                          ),
                        if (vig > 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${tx(context, 'tripVig')}: ≈ ${fmtMoney(vig, 'EUR', lang, 2)}')),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(tx(context, 'tripNote'), style: t.textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }
}
