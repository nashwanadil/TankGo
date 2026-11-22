import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../countries.dart';
import '../data.dart';
import '../premium.dart';
import '../settings.dart';
import '../strings.dart';
import 'brand.dart';
import 'calc_page.dart';
import 'compare_page.dart';
import 'country_sheet.dart';
import 'lang_flag.dart';
import 'paywall.dart';
import 'trip_page.dart';
import 'fmt.dart';
import 'settings_page.dart';
import 'stations_page.dart';

// Diesel takes the chosen colour theme, so it matches the hero card; LPG avoids clashing with the emerald theme.
Map<String, Color> get _fuelDark => {'e95': gold, 'diesel': Color.lerp(brand, Colors.white, 0.45)!, 'lpg': pal.id == 'emerald' ? lpgAltDark : fuelLpgDark};
Map<String, Color> get _fuelLight => {'e95': fuelE95Light, 'diesel': brand, 'lpg': pal.id == 'emerald' ? lpgAltLight : positive};
Color fuelColor(BuildContext c, String f) => (Theme.of(c).brightness == Brightness.dark ? _fuelDark : _fuelLight)[f]!;
const fuelOrder = ['e95', 'diesel', 'lpg'];

String fuelName(BuildContext c, String f) => f == 'lpg' ? 'LPG' : tr(c, f);

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.settings, required this.api, required this.premium});
  final Settings settings;
  final Api api;
  final Premium premium;
  @override
  State<HomePage> createState() => _HomePageState();
}

bool _startHandled = false;

class _HomePageState extends State<HomePage> {
  late Future<Loaded<Map<String, Entry>>> _latest = widget.api.latest();
  late final Future<Signal?> _signal = widget.api.signal();
  Future<Map<String, Series>>? _hist;
  String? _histCc;
  late String _fuel = widget.settings.fuel;
  late String _defFuel = widget.settings.fuel;

  /// Countries that have station price files; the stations card sits high only for those.
  Set<String>? _stationCountries;
  int _days = 30;
  (DateTime, double)? _touch;
  int? _touchIdx;
  (DateTime, double)? _pin;
  bool _pulse = false;

  @override
  void initState() {
    super.initState();
    widget.premium.addListener(_onPremium);
    widget.settings.addListener(_onSettings);
    widget.api.stationIndex().then((v) {
      if (mounted && v != null) setState(() => _stationCountries = v);
    });
    if (widget.premium.isPremium) _days = 365;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!widget.settings.noteSeen && mounted) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            icon: const Icon(Icons.info_outline),
            title: Text(tr(c, 'noteTitle')),
            content: Text(tr(c, 'noteBody')),
            actions: [FilledButton(onPressed: () => Navigator.pop(c), child: Text(tr(c, 'ok')))],
          ),
        );
        widget.settings.setNoteSeen();
      }
      await _openStartPage();
    });
  }

  void _openStations() => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => StationsPage(api: widget.api, settings: widget.settings, fuel: _fuel)));

  Future<void> _openTrip() async {
    final all = (await _latest).value;
    if (all == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => TripPage(entries: all, home: widget.settings.country!, premium: widget.premium, fuel: _fuel, settings: widget.settings)),
    );
  }

  /// Opens the page chosen in settings once per app launch; back returns to the home screen.
  Future<void> _openStartPage() async {
    if (_startHandled || !mounted) return;
    _startHandled = true;
    switch (widget.settings.startPage) {
      case 'stations':
        _openStations();
      case 'trip':
        await _openTrip();
    }
  }

  /// A new default fuel from settings applies at once everywhere; picking a fuel on the home screen never changes the default.
  void _onSettings() {
    if (!mounted || widget.settings.fuel == _defFuel) return;
    setState(() {
      _defFuel = widget.settings.fuel;
      _fuel = _defFuel;
      _touch = null;
      _pin = null;
    });
  }

  void _onPremium() {
    if (!mounted) return;
    setState(() {
      if (!widget.premium.isPremium && _days > freeDays) _days = freeDays;
    });
  }

  @override
  void dispose() {
    widget.premium.removeListener(_onPremium);
    widget.settings.removeListener(_onSettings);
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _latest = widget.api.latest();
      _hist = null;
      _pin = null;
    });
    await _latest;
  }

  @override
  Widget build(BuildContext context) {
    final cc = widget.settings.country!;
    final country = countryByCode(cc)!;
    final lang = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        titleSpacing: 12,
        title: Row(
          children: [
            Flexible(
              child: ActionChip(
                avatar: Text(country.flag, style: const TextStyle(fontSize: 20)),
                label: Text(country.name, overflow: TextOverflow.ellipsis),
                onPressed: () async {
                  final v = await pickCountry(context);
                  if (v != null && v != cc) {
                    await widget.settings.setCountry(v);
                    setState(() {
                      _hist = null;
                      _pin = null;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 6),
            _langMenu(context, lang),
          ],
        ),
        actions: [
          IconButton(
            tooltip: tr(context, 'calc'),
            icon: const Icon(Icons.calculate_outlined),
            onPressed: () async {
              final e = (await _latest).value?[cc];
              if (e == null || !context.mounted) return;
              Navigator.push(context, MaterialPageRoute<void>(builder: (_) => CalcPage(entry: e)));
            },
          ),
          IconButton(
            tooltip: tx(context, 'trip'),
            icon: const Icon(Icons.map_outlined),
            onPressed: _openTrip,
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () async {
              final before = widget.settings.startPage;
              await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SettingsPage(settings: widget.settings)));
              if (mounted) setState(() {}); // colours may have changed
              // Having just chosen a start page, going back opens it right away.
              if (!mounted || widget.settings.startPage == before) return;
              switch (widget.settings.startPage) {
                case 'stations':
                  _openStations();
                case 'trip':
                  await _openTrip();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<Loaded<Map<String, Entry>>>(
          future: _latest,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final entry = snap.data?.value?[cc];
            if (entry == null) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(tr(context, 'noData'))),
                  Center(
                    child: TextButton(onPressed: _refresh, child: Text(tr(context, 'retry'))),
                  ),
                ],
              );
            }
            final hasStations = _stationCountries?.contains(cc) ?? false;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                if (snap.data!.offline)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(padding: const EdgeInsets.all(12), child: Text(tr(context, 'offline'))),
                  ),
                _hero(context, entry, lang),
                const SizedBox(height: 8),
                _tiles(context, entry, lang),
                if (hasStations) ...[_stationsCard(context)],
                const SizedBox(height: 8),
                _chartCard(context, cc, entry, lang),
                const SizedBox(height: 8),
                _compareCard(context, snap.data!.value!, cc),
                if (!hasStations) ...[const SizedBox(height: 8), _stationsCard(context)],
                _outlook(context, lang),
              ],
            );
          },
        ),
      ),
    );
  }

  /// One bright gold pulse on the hero, so a changed price is noticed.
  Future<void> _glow() async {
    setState(() => _pulse = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _pulse = false);
  }

  Future<void> _pickDate(Entry e) async {
    final ser = (await _hist)?[_fuel];
    if (ser == null || ser.points.isEmpty || !mounted) return;
    final first = DateUtils.dateOnly(ser.points.first.$1), last = DateUtils.dateOnly(ser.points.last.$1);
    var init = DateUtils.dateOnly(_pin?.$1 ?? e.date);
    if (init.isBefore(first)) init = first;
    if (init.isAfter(last)) init = last;
    final d = await showDialog<DateTime>(
      context: context,
      builder: (c) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.premium.isPremium)
              Container(
                color: brandDark,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium, color: gold, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tx(c, 'calHelp'),
                        style: const TextStyle(color: cream, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            Builder(
              builder: (c) {
                final th = Theme.of(c);
                final dark = th.brightness == Brightness.dark;
                final dayInk = dark ? cream : darkBrown;
                return Stack(
                  children: [
                    Positioned(top: 0, left: 0, right: 0, height: 52, child: Container(color: brandDark)),
                    Theme(
                      data: th.copyWith(
                        colorScheme: th.colorScheme.copyWith(onSurface: cream, onSurfaceVariant: cream),
                        datePickerTheme: th.datePickerTheme.copyWith(
                          weekdayStyle: TextStyle(color: dayInk.withValues(alpha: 0.7), fontWeight: FontWeight.w600),
                          dayForegroundColor: WidgetStateProperty.resolveWith(
                            (s) => s.contains(WidgetState.selected)
                                ? th.colorScheme.onPrimary
                                : s.contains(WidgetState.disabled)
                                ? dayInk.withValues(alpha: 0.3)
                                : dayInk,
                          ),
                          yearForegroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? th.colorScheme.onPrimary : dayInk),
                        ),
                      ),
                      child: CalendarDatePicker(initialDate: init, firstDate: first, lastDate: last, onDateChanged: (v) => Navigator.pop(c, v)),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
    if (d == null || !mounted) return;
    if (!widget.premium.isPremium && d.isBefore(DateUtils.dateOnly(e.date).subtract(const Duration(days: freeDays)))) {
      showPaywall(context, widget.premium);
      return;
    }
    var pt = ser.points.first;
    for (final p in ser.points) {
      if (p.$1.isAfter(d)) break;
      pt = p;
    }
    setState(() {
      _touch = null;
      _pin = pt.$1 == ser.points.last.$1 && e.date == pt.$1 ? null : pt;
    });
    _glow();
  }

  Widget _hero(BuildContext c, Entry e, String lang) {
    if (!e.prices.containsKey(_fuel)) _fuel = fuelOrder.firstWhere(e.prices.containsKey);
    final touching = _touch != null;
    final shown = _touch ?? _pin;
    final v = shown?.$2 ?? e.prices[_fuel]!;
    final date = shown?.$1 ?? e.date;
    final stale = shown == null && DateTime.now().difference(e.date).inDays > 14;
    final p = e.prev?[_fuel];
    Widget? chg;
    if (shown == null && p != null) {
      final d = e.prices[_fuel]! - p;
      final flat = d.abs() < 0.0005;
      final cc = flat ? cream : (d > 0 ? riseSoft : fallSoft);
      chg = Text(
        '${flat
            ? '→'
            : d > 0
            ? '▲'
            : '▼'} ${d > 0 ? '+' : ''}${fmtNum(d * 100, lang, 1)} ${e.currency == 'USD' ? 'c' : 'ct'}',
        style: TextStyle(color: cc, fontWeight: FontWeight.w700, fontSize: 16),
      );
    }
    return AnimatedScale(
      scale: _pulse ? 1.03 : 1,
      duration: const Duration(milliseconds: 650), // slow, like slow motion, both ways
      curve: Curves.easeInOutCubic,
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [brandLight, brandDark]),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: shown != null ? gold : gold.withValues(alpha: 0.35), width: shown != null ? 3 : 1.5),
        boxShadow: _pulse
            ? [BoxShadow(color: gold.withValues(alpha: 0.9), blurRadius: 18, spreadRadius: 2)]
            : [
                BoxShadow(
                  color: brand.withValues(alpha: touching ? 0.55 : 0.3),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Column(
        children: [
          Builder(
            builder: (bc) => InkWell(
              borderRadius: BorderRadius.circular(rElement),
              onTap: () async {
                final box = bc.findRenderObject()! as RenderBox;
                final overlay = Overlay.of(bc).context.findRenderObject()! as RenderBox;
                final r = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
                const w = 240.0;
                final left = (r.center.dx - w / 2).clamp(12.0, overlay.size.width - w - 12);
                final f = await showMenu<String>(
                  context: bc,
                  position: RelativeRect.fromLTRB(left, r.bottom + 6, overlay.size.width - left - w, 0),
                  constraints: const BoxConstraints(minWidth: w, maxWidth: w),
                  color: brandDark,
                  elevation: 4,
                  initialValue: _fuel,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(rElement),
                    side: BorderSide(color: gold.withValues(alpha: 0.6)),
                  ),
                  items: [
                    for (final f in fuelOrder.where(e.prices.containsKey))
                      PopupMenuItem(
                        value: f,
                        height: 52,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: _fuelDark[f]),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                fuelName(c, f),
                                style: TextStyle(color: f == _fuel ? gold : cream, fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(
                              fmtMoney(e.prices[f]!, e.currency, lang),
                              style: const TextStyle(color: cream, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.check, size: 18, color: f == _fuel ? gold : Colors.transparent),
                          ],
                        ),
                      ),
                  ],
                );
                if (f != null && mounted) {
                  setState(() {
                    _fuel = f;
                    _touch = null;
                    _pin = null;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 8, 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(rElement),
                  color: Colors.black.withValues(alpha: 0.18),
                  border: Border.all(color: gold.withValues(alpha: 0.55)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fuelName(c, _fuel).toUpperCase(),
                      style: const TextStyle(color: gold, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1.6),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.expand_more, color: gold, size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '\u2066${moneyRaw(v, e.currency, lang)} ${unitLabel(e)}\u2069',
              style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w800),
            ),
          ),
          if (e.unit == 'gal') Text('≈ ${fmtMoney(e.perLitre(v), e.currency, lang)} /L', style: const TextStyle(color: cream)),
          if (chg != null) Padding(padding: const EdgeInsets.only(top: 4), child: chg),
          const SizedBox(height: 16),
          Material(
            color: stale ? riseSoft : gold,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _pickDate(e),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 9, 10, 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(stale ? Icons.warning_amber_rounded : Icons.event, size: 22, color: darkBrown),
                    const SizedBox(width: 8),
                    Text(
                      fmtDate(date, lang),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: darkBrown),
                    ),
                    const Icon(Icons.arrow_drop_down, color: darkBrown),
                  ],
                ),
              ),
            ),
          ),
          if (_pin != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: cream,
                  backgroundColor: Colors.black.withValues(alpha: 0.18),
                  side: const BorderSide(color: cream),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.update, size: 18),
                label: Text(tr(c, 'today'), style: const TextStyle(fontWeight: FontWeight.w700)),
                onPressed: () => setState(() => _pin = null),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            '${tr(c, e.frequency == 'daily' ? 'daily' : 'weekly')} · ${e.source}',
            style: const TextStyle(color: cream, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
    );
  }

  Widget _langMenu(BuildContext context, String lang) {
    final cs = Theme.of(context).colorScheme;
    final items = languages.where((l) => !l.$2.startsWith('English ('));
    return PopupMenuButton<String>(
      tooltip: tr(context, 'language'),
      initialValue: lang,
      color: brandDark,
      elevation: 4,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      constraints: const BoxConstraints(minWidth: 230, maxHeight: 440),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rElement),
        side: BorderSide(color: gold.withValues(alpha: 0.6)),
      ),
      onSelected: widget.settings.setLang,
      itemBuilder: (_) => [
        for (final (code, name, flag) in items)
          PopupMenuItem(
            value: code,
            height: 46,
            child: Row(
              children: [
                LangFlag(code: code, flag: flag, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(color: code == lang ? gold : cream, fontWeight: code == lang ? FontWeight.w800 : FontWeight.w500),
                  ),
                ),
                Text(
                  code.toUpperCase(),
                  style: TextStyle(color: cream.withValues(alpha: 0.55), fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Icon(Icons.check, size: 18, color: code == lang ? gold : Colors.transparent),
              ],
            ),
          ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 6, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(rElement),
          border: Border.all(color: Theme.of(context).dividerColor),
          color: Theme.of(context).cardTheme.color,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              lang.toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary, fontSize: 14),
            ),
            Icon(Icons.expand_more, size: 18, color: cs.primary),
          ],
        ),
      ),
    );
  }

  Widget _outlook(BuildContext c, String lang) {
    return FutureBuilder<Signal?>(
      future: _signal,
      builder: (c, s) {
        final sig = s.data;
        if (sig == null) return const SizedBox();
        final premium = widget.premium.isPremium;
        final (icon, col, key) = switch (sig.direction) {
          'up' => (Icons.trending_up, negative, 'outUp'),
          'down' => (Icons.trending_down, positive, 'outDown'),
          _ => (Icons.trending_flat, Theme.of(c).colorScheme.onSurface, 'outFlat'),
        };
        return Card(
          child: ListTile(
            leading: Icon(premium ? icon : Icons.lock, color: premium ? col : gold, size: 30),
            title: Text('${tx(c, 'outlook')}${premium ? ': ${tx(c, key)}' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: premium ? Text(tx(c, 'outWhy').replaceFirst('{d}', '${sig.deltaCt > 0 ? '+' : ''}${fmtNum(sig.deltaCt, lang, 1)}')) : Text(tx(c, 'f4')),
            trailing: premium ? null : Text(tx(c, 'unlock'), style: const TextStyle(fontWeight: FontWeight.w800)),
            onTap: premium ? null : () => showPaywall(c, widget.premium),
          ),
        );
      },
    );
  }

  Widget _tiles(BuildContext c, Entry e, String lang) {
    final fuels = fuelOrder.where(e.prices.containsKey).toList();
    return Row(
      children: [
        for (final f in fuels)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                borderRadius: BorderRadius.circular(rCard),
                onTap: () => setState(() {
                  _fuel = f;
                  _touch = null;
                  _pin = null;
                }),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(rCard),
                    side: BorderSide(color: _fuel == f ? fuelColor(c, f) : Theme.of(c).dividerColor.withValues(alpha: 0.4), width: _fuel == f ? 2 : 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    child: Column(
                      children: [
                        Text(
                          fuelName(c, f),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(fmtMoney(e.prices[f]!, e.currency, lang), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _stationsCard(BuildContext c) {
    return Card(
      key: const ValueKey('stNear'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rCard),
        side: const BorderSide(color: gold, width: 2),
      ),
      child: ListTile(
        leading: const Icon(Icons.local_gas_station, color: gold, size: 30),
        title: Text(tx(c, 'stNear'), style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(tx(c, 'stCovered')),
        trailing: Icon(Icons.chevron_right, color: Theme.of(c).colorScheme.onSurface),
        onTap: _openStations,
      ),
    );
  }

  Widget _chartCard(BuildContext c, String cc, Entry e, String lang) {
    if (_histCc != cc || _hist == null) {
      _histCc = cc;
      _hist = widget.api.historyAll(cc);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(c, 'trend'), style: Theme.of(c).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final (label, days) in const [('1W', 7), ('1M', 30), ('3M', 90), ('1Y', 365), ('2Y', 730)])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ChoiceChip(
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                        labelPadding: EdgeInsets.zero,
                        label: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!widget.premium.isPremium && days > freeDays) const Padding(padding: EdgeInsetsDirectional.only(end: 2), child: Icon(Icons.lock, size: 12)),
                            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        selected: _days == days,
                        onSelected: (_) {
                          if (!widget.premium.isPremium && days > freeDays) {
                            showPaywall(context, widget.premium);
                            return;
                          }
                          setState(() {
                            _days = days;
                            _touch = null;
                          });
                        },
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 244,
              child: FutureBuilder<Map<String, Series>>(
                future: _hist,
                builder: (c, s) {
                  final ser = s.data?[_fuel];
                  if (ser == null || ser.points.length < 2) return const SizedBox();
                  final last = ser.points.last.$1;
                  final cut = last.subtract(Duration(days: _days));
                  var pts = ser.points.where((p) => !p.$1.isBefore(cut)).toList();
                  if (pts.length < 2) pts = ser.points.sublist(ser.points.length - 2);
                  final vals = pts.map((p) => ser.unit == 'gal' ? p.$2 : p.$2).toList();
                  final lo = vals.reduce((a, b) => a < b ? a : b), hi = vals.reduce((a, b) => a > b ? a : b);
                  final pad = ((hi - lo) * 0.15).clamp(0.01, 10.0);
                  final col = fuelColor(c, _fuel);
                  // The tooltip follows the finger; after release it stays on the picked day (the pin).
                  final pinIdx = _pin == null ? -1 : pts.indexWhere((p) => p.$1 == _pin!.$1);
                  final ti = _touchIdx != null && _touchIdx! < pts.length ? _touchIdx : (pinIdx >= 0 ? pinIdx : null);
                  final bar = LineChartBarData(
                    spots: [for (var i = 0; i < pts.length; i++) FlSpot(i.toDouble(), pts[i].$2)],
                    isCurved: false,
                    color: col,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: col.withValues(alpha: 0.15)),
                    showingIndicators: ti == null ? const [] : [ti],
                  );
                  const leftW = 44.0;
                  void scrub(Offset pos, double w) {
                    final i = (((pos.dx - leftW) / (w - leftW)) * (pts.length - 1)).round().clamp(0, pts.length - 1);
                    if (i != _touchIdx) {
                      setState(() {
                        _touchIdx = i;
                        _touch = pts[i];
                      });
                    }
                  }

                  // Lifting the finger keeps the picked day in the hero (like the calendar); the hero glows
                  // so the change is noticed, and the "latest" button there returns to today.
                  void end() {
                    final t = _touch;
                    if (_touchIdx != null || t != null) {
                      setState(() {
                        _touchIdx = null;
                        _touch = null;
                        if (t != null) _pin = t.$1 == ser.points.last.$1 ? null : t;
                      });
                      if (t != null && _pin != null) _glow();
                    }
                  }

                  return LayoutBuilder(
                    builder: (c, box) => Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (e) => scrub(e.localPosition, box.maxWidth),
                      onPointerMove: (e) => scrub(e.localPosition, box.maxWidth),
                      onPointerUp: (_) => end(),
                      onPointerCancel: (_) => end(),
                      child: GestureDetector(
                        // Claims horizontal drags so the page does not steal the scrub gesture.
                        onHorizontalDragUpdate: (_) {},
                        child: Padding(
                          padding: const EdgeInsets.only(top: 44),
                          child: LineChart(
                            duration: Duration.zero,
                            LineChartData(
                              minY: lo - pad,
                              maxY: hi + pad,
                              gridData: const FlGridData(drawVerticalLine: false),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(),
                                rightTitles: const AxisTitles(),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 44,
                                    interval: (hi - lo + 2 * pad) / 4,
                                    getTitlesWidget: (v, m) => Text(fmtNum(v, lang, 2), style: const TextStyle(fontSize: 10)),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 22,
                                    interval: (pts.length / 4).ceilToDouble(),
                                    getTitlesWidget: (v, m) {
                                      final i = v.toInt();
                                      if (i < 0 || i >= pts.length || (i != pts.length - 1 && pts.length - 1 - i < (pts.length / 4).ceil() * 0.6)) return const SizedBox();
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(fmtShortDate(pts[i].$1, lang), style: const TextStyle(fontSize: 10)),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              showingTooltipIndicators: ti == null
                                  ? const []
                                  : [
                                      ShowingTooltipIndicators([LineBarSpot(bar, 0, bar.spots[ti])]),
                                    ],
                              lineTouchData: LineTouchData(
                                handleBuiltInTouches: false,
                                getTouchLineStart: (_, _) => -double.infinity,
                                getTouchLineEnd: (_, _) => double.infinity,
                                getTouchedSpotIndicator: (bar, idx) => [
                                  for (final _ in idx)
                                    TouchedSpotIndicatorData(
                                      FlLine(color: col, strokeWidth: 1.5, dashArray: const [4, 3]),
                                      FlDotData(
                                        getDotPainter: (_, _, _, _) => FlDotCirclePainter(radius: 5, color: col, strokeWidth: 2, strokeColor: Colors.white),
                                      ),
                                    ),
                                ],
                                touchTooltipData: LineTouchTooltipData(
                                  showOnTopOfTheChartBoxArea: true,
                                  fitInsideHorizontally: true,
                                  tooltipMargin: 0,
                                  tooltipBorderRadius: BorderRadius.circular(10),
                                  getTooltipColor: (_) => col,
                                  getTooltipItems: (spots) => [
                                    for (final sp in spots)
                                      LineTooltipItem(
                                        '${fmtMoney(sp.y, ser.currency, lang)}\n',
                                        TextStyle(color: Theme.of(c).brightness == Brightness.dark ? darkBrown : Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                                        children: [
                                          TextSpan(
                                            text: fmtDate(pts[sp.spotIndex].$1, lang),
                                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              lineBarsData: [bar],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compareCard(BuildContext c, Map<String, Entry> all, String cc) {
    if (all[cc]?.currency != 'EUR') return const SizedBox();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${tx(c, 'compare')} · ${fuelName(c, _fuel)}', style: Theme.of(c).textTheme.titleMedium),
            const SizedBox(height: 10),
            CompareList(
              entries: all,
              home: cc,
              premium: widget.premium,
              fuel: _fuel,
              onShowAll: () => Navigator.push(
                c,
                MaterialPageRoute<void>(
                  builder: (_) => ComparePage(entries: all, home: cc, premium: widget.premium, fuel: _fuel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
