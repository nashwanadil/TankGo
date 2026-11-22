import 'package:material_ui/material_ui.dart';

import '../countries.dart';
import '../data.dart';
import '../premium.dart';
import '../settings.dart';
import '../strings.dart';
import '../trip.dart';
import 'fmt.dart';
import 'number_row.dart';
import 'home.dart' show fuelName, fuelOrder;
import 'paywall.dart';
import 'brand.dart';

class TripPage extends StatefulWidget {
  const TripPage({super.key, required this.entries, required this.home, required this.premium, this.fuel = 'e95', this.settings});
  final Map<String, Entry> entries;
  final String home;
  final Premium premium;

  /// Remembers whether the how-it-works card was closed.
  final Settings? settings;

  /// Fuel selected on the home screen (follows the default fuel from settings).
  final String fuel;
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
  late String _fuel = widget.fuel;
  bool _full = true;
  late bool _helpHidden = widget.settings?.tripHelpHidden ?? false;

  List<Country> get _eu => countries.where((c) => widget.entries[c.code]?.currency == 'EUR').toList();

  /// Each tap on "add" proposes the next neighbour of the starting country not yet on the route,
  /// then neighbours of the last stop, then any other EU country.
  String _nextCountry() {
    final used = {for (final l in _legs) l.cc};
    final eu = {for (final c in _eu) c.code};
    final order = [
      if (_legs.isNotEmpty) ...?neighbours[_legs.first.cc],
      if (_legs.isNotEmpty) ...?neighbours[_legs.last.cc],
      ..._eu.map((c) => c.code),
    ];
    return order.firstWhere((c) => eu.contains(c) && !used.contains(c), orElse: () => _eu.first.code);
  }

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

  Future<String?> _pickEu(BuildContext context) => showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (c) => ListView(
      children: [
        for (final x in _eu)
          ListTile(
            leading: Text(x.flag, style: const TextStyle(fontSize: 26)),
            title: Text(x.name),
            onTap: () => Navigator.pop(c, x.code),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return ListenableBuilder(
      listenable: widget.premium,
      builder: (context, _) {
        final t = Theme.of(context);
        final demo = !widget.premium.isPremium;
        final fuels = fuelOrder.where((f) => _eu.any((c) => widget.entries[c.code]!.prices.containsKey(f))).toList();
        if (fuels.isNotEmpty && !fuels.contains(_fuel)) _fuel = fuels.first;
        final prices = {
          for (final c in _eu)
            if (widget.entries[c.code]!.prices[_fuel] != null) c.code: widget.entries[c.code]!.prices[_fuel]!,
        };
        final legs = demo ? demoRoute : [for (final l in _legs) Leg(l.cc, _n(l.km))];
        final plan = planTrip(legs, prices, tank: demo ? 50 : _n(_tank), consumption: demo ? 6.5 : _n(_cons), startFull: demo || _full);
        final vig = legs.where((l) => l.km > 0).map((l) => l.cc).toSet().fold(0.0, (a, cc) => a + (vignetteEur[cc] ?? 0));
        return Scaffold(
          appBar: AppBar(
            title: Text(tx(context, 'trip')),
            actions: [
              if (_helpHidden)
                IconButton(
                  key: const ValueKey('tripHelp'),
                  tooltip: tx(context, 'tripHowTitle'),
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (c) => AlertDialog(
                      icon: const Icon(Icons.info_outline),
                      title: Text(tx(c, 'tripHowTitle')),
                      content: Text(tx(c, 'tripHow')),
                      actions: [FilledButton(onPressed: () => Navigator.pop(c), child: Text(tr(c, 'ok')))],
                    ),
                  ),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!_helpHidden)
                Card(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 4, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(padding: const EdgeInsets.only(top: 8), child: Icon(Icons.info_outline, color: t.colorScheme.primary)),
                        const SizedBox(width: 10),
                        Expanded(child: Padding(padding: const EdgeInsets.only(top: 8), child: Text(tx(context, 'tripHow')))),
                        IconButton(
                          key: const ValueKey('tripHelpClose'),
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            setState(() => _helpHidden = true);
                            widget.settings?.setTripHelpHidden(true);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              if (demo)
                Card(
                  color: brandDark,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.workspace_premium, color: gold),
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
                          style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: darkBrown),
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
                NumberRow(icon: Icons.local_gas_station, label: tx(context, 'tripTank'), controller: _tank, suffix: ' L', onChanged: (_) => setState(() {})),
                NumberRow(icon: Icons.water_drop_outlined, label: tx(context, 'tripCons'), controller: _cons, onChanged: (_) => setState(() {})),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(rCard),
                    side: BorderSide(color: t.colorScheme.primary, width: 2),
                  ),
                  child: SwitchListTile(
                    secondary: Icon(Icons.battery_full, color: t.colorScheme.primary, size: 28),
                    title: Text(tx(context, 'tripFull'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    value: _full,
                    onChanged: (v) => setState(() => _full = v),
                  ),
                ),
                const SizedBox(height: 8),
                if (_legs.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(tx(context, 'tripEmpty'))),
                if (_legs.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.drag_indicator, size: 18, color: t.hintColor),
                        const SizedBox(width: 6),
                        Expanded(child: Text(tx(context, 'tripReorder'), style: t.textTheme.bodySmall)),
                      ],
                    ),
                  ),
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorderItem: (from, to) => setState(() => _legs.insert(to, _legs.removeAt(from))),
                  children: [
                    for (final (i, l) in _legs.indexed)
                      ReorderableDelayedDragStartListener(
                        key: ObjectKey(l),
                        index: i,
                        child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(rCard),
                      side: BorderSide(color: t.dividerColor),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsetsDirectional.only(start: 12, end: 4),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: t.colorScheme.primary,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(color: t.colorScheme.onPrimary, fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                      title: InkWell(
                        borderRadius: BorderRadius.circular(rElement),
                        onTap: () async {
                          final v = await _pickEu(context);
                          if (v != null) setState(() => l.cc = v);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Text(countryByCode(l.cc)?.flag ?? '', style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  countryByCode(l.cc)?.name ?? l.cc,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 84,
                            child: TextField(
                              controller: l.km,
                              onTap: () => selectAll(l.km),
                              textAlign: TextAlign.end,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                              decoration: const InputDecoration(isDense: true, border: InputBorder.none, suffixText: ' km'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => setState(() => _legs.removeAt(i).km.dispose())),
                        ],
                      ),
                    ),
                  ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rCard)),
                    side: BorderSide(color: t.colorScheme.primary, width: 1.5),
                  ),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: Text(tx(context, 'tripAdd'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () => setState(() => _legs.add(_LegRow(_nextCountry(), '200'))),
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
                        for (final s in plan.stops.where((s) => s.litres >= 0.5))
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
                              style: const TextStyle(color: positive, fontWeight: FontWeight.w600),
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
