import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../countries.dart';
import '../data.dart';
import '../premium.dart';
import '../settings.dart';
import '../strings.dart';
import 'brand.dart';
import 'compare_page.dart';
import 'country_sheet.dart';
import 'paywall.dart';
import 'trip_page.dart';
import 'fmt.dart';
import 'settings_page.dart';

const _fuelDark = {'e95': Color(0xFFE0B860), 'diesel': Color(0xFFE8808F), 'lpg': Color(0xFF7FC4A5)};
const _fuelLight = {'e95': Color(0xFFB98A24), 'diesel': Color(0xFF9F2B3E), 'lpg': Color(0xFF2E8B6A)};
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

class _HomePageState extends State<HomePage> {
  late Future<Loaded<Map<String, Entry>>> _latest = widget.api.latest();
  late final Future<Signal?> _signal = widget.api.signal();
  Future<Map<String, Series>>? _hist;
  String? _histCc;
  String _fuel = 'e95';
  int _days = 30;
  (DateTime, double)? _touch;
  int? _touchIdx;
  (DateTime, double)? _pin;
  bool _pulse = false;
  final _km = TextEditingController(text: '100');
  final _cons = TextEditingController(text: '6.5');

  @override
  void initState() {
    super.initState();
    widget.premium.addListener(_onPremium);
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
    _km.dispose();
    _cons.dispose();
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
        title: ActionChip(
          avatar: Text(country.flag, style: const TextStyle(fontSize: 20)),
          label: Text(country.name),
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
        actions: [
          IconButton(
            tooltip: tx(context, 'compare'),
            icon: const Icon(Icons.public),
            onPressed: () async {
              final all = (await _latest).value;
              if (all == null || !context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ComparePage(entries: all, home: cc, premium: widget.premium, fuel: _fuel),
                ),
              );
            },
          ),
          IconButton(
            tooltip: tx(context, 'trip'),
            icon: const Icon(Icons.map_outlined),
            onPressed: () async {
              final all = (await _latest).value;
              if (all == null || !context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => TripPage(entries: all, home: cc, premium: widget.premium),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SettingsPage(settings: widget.settings))),
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
                const SizedBox(height: 8),
                _outlook(context, lang),
                _chartCard(context, cc, entry, lang),
                const SizedBox(height: 8),
                _calcCard(context, entry, lang),
              ],
            );
          },
        ),
      ),
    );
  }

  void _glow() {
    setState(() => _pulse = true);
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _pulse = false);
    });
  }

  Future<void> _pickDate(Entry e) async {
    final ser = (await _hist)?[_fuel];
    if (ser == null || ser.points.isEmpty || !mounted) return;
    final first = DateUtils.dateOnly(ser.points.first.$1), last = DateUtils.dateOnly(ser.points.last.$1);
    var init = DateUtils.dateOnly(_pin?.$1 ?? e.date);
    if (init.isBefore(first)) init = first;
    if (init.isAfter(last)) init = last;
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: first,
      lastDate: last,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: widget.premium.isPremium ? null : '👑 ${tx(context, 'calHelp')}',
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
      final cc = flat ? const Color(0xFFF5ECE0) : (d > 0 ? const Color(0xFFFFB4AB) : const Color(0xFFA5E8C0));
      chg = Text(
        '${flat
            ? '→'
            : d > 0
            ? '▲'
            : '▼'} ${d > 0 ? '+' : ''}${fmtNum(d * 100, lang, 1)} ${e.currency == 'USD' ? 'c' : 'ct'}',
        style: TextStyle(color: cc, fontWeight: FontWeight.w700, fontSize: 16),
      );
    }
    const cream = Color(0xFFF5ECE0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF9E2F42), Color(0xFF6B1A2E)]),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: shown != null ? gold : gold.withValues(alpha: 0.35), width: shown != null ? 3 : 1.5),
        boxShadow: _pulse
            ? [BoxShadow(color: gold.withValues(alpha: 0.75), blurRadius: 40, spreadRadius: 6)]
            : [
                BoxShadow(
                  color: const Color(0xFF8F2A39).withValues(alpha: touching ? 0.55 : 0.3),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Column(
        children: [
          PopupMenuButton<String>(
            tooltip: '',
            initialValue: _fuel,
            onSelected: (f) => setState(() {
              _fuel = f;
              _touch = null;
              _pin = null;
            }),
            itemBuilder: (_) => [for (final f in fuelOrder.where(e.prices.containsKey)) PopupMenuItem(value: f, child: Text(fuelName(c, f)))],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fuelName(c, _fuel).toUpperCase(),
                    style: const TextStyle(color: gold, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1.6),
                  ),
                  const Icon(Icons.arrow_drop_down, color: gold),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${fmtMoney(v, e.currency, lang)} ${unitLabel(e)}',
              style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w800),
            ),
          ),
          if (e.unit == 'gal') Text('≈ ${fmtMoney(e.perLitre(v), e.currency, lang)} /L', style: const TextStyle(color: cream)),
          if (chg != null) Padding(padding: const EdgeInsets.only(top: 4), child: chg),
          const SizedBox(height: 16),
          Material(
            color: stale ? const Color(0xFFFFB4AB) : gold,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _pickDate(e),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 9, 10, 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(stale ? Icons.warning_amber_rounded : Icons.event, size: 22, color: const Color(0xFF2A1D17)),
                    const SizedBox(width: 8),
                    Text(
                      fmtDate(date, lang),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF2A1D17)),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Color(0xFF2A1D17)),
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
          'up' => (Icons.trending_up, const Color(0xFFD9534F), 'outUp'),
          'down' => (Icons.trending_down, const Color(0xFF2E8B6A), 'outDown'),
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
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() {
                  _fuel = f;
                  _touch = null;
                  _pin = null;
                }),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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
            Wrap(
              spacing: 8,
              children: [
                for (final (label, days) in const [('1W', 7), ('1M', 30), ('3M', 90), ('1Y', 365), ('2Y', 730)])
                  ChoiceChip(
                    avatar: !widget.premium.isPremium && days > freeDays ? const Icon(Icons.lock, size: 14) : null,
                    label: Text(label),
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
                  final ti = _touchIdx != null && _touchIdx! < pts.length ? _touchIdx : null;
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

                  void end() {
                    if (_touchIdx != null || _touch != null) {
                      setState(() {
                        _touchIdx = null;
                        _touch = null;
                      });
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
                                      if (i < 0 || i >= pts.length) return const SizedBox();
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(fmtDate(pts[i].$1, lang), style: const TextStyle(fontSize: 9)),
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
                                        TextStyle(color: Theme.of(c).brightness == Brightness.dark ? const Color(0xFF2A1D17) : Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
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

  Widget _calcCard(BuildContext c, Entry e, String lang) {
    double num(TextEditingController t) => double.tryParse(t.text.replaceAll(',', '.')) ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(c, 'calc'), style: Theme.of(c).textTheme.titleMedium),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _km,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: tr(c, 'distance'), border: const OutlineInputBorder()),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _cons,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: tr(c, 'consumption'), border: const OutlineInputBorder()),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final f in fuelOrder.where(e.prices.containsKey))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(fuelName(c, f))),
                    Text(fmtMoney(e.perLitre(e.prices[f]!) * num(_cons) * num(_km) / 100, e.currency, lang, 2), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
