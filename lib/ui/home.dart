import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import '../countries.dart';
import '../data.dart';
import '../settings.dart';
import '../strings.dart';
import 'country_sheet.dart';
import 'fmt.dart';
import 'settings_page.dart';

const fuelColors = {'e95': Color(0xFF2563EB), 'diesel': Color(0xFFD97706), 'lpg': Color(0xFF0D9488)};
const fuelOrder = ['e95', 'diesel', 'lpg'];

String fuelName(BuildContext c, String f) => f == 'lpg' ? 'LPG' : tr(c, f);

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.settings, required this.api});
  final Settings settings;
  final Api api;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<Loaded<Map<String, Entry>>> _latest = widget.api.latest();
  Future<Map<String, Series>>? _hist;
  String? _histCc;
  String _fuel = 'e95';
  int _months = 12;
  final _km = TextEditingController(text: '100');
  final _cons = TextEditingController(text: '6.5');

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _km.dispose();
    _cons.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _latest = widget.api.latest();
      _hist = null;
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
              setState(() => _hist = null);
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
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
              return ListView(children: [
                const SizedBox(height: 120),
                Center(child: Text(tr(context, 'noData'))),
                Center(child: TextButton(onPressed: _refresh, child: Text(tr(context, 'retry')))),
              ]);
            }
            return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
              if (snap.data!.offline)
                Card(color: Theme.of(context).colorScheme.errorContainer, child: Padding(padding: const EdgeInsets.all(12), child: Text(tr(context, 'offline')))),
              _freshness(context, entry, lang),
              const SizedBox(height: 8),
              for (final f in fuelOrder.where(entry.prices.containsKey)) _priceCard(context, entry, f, lang),
              const SizedBox(height: 8),
              _chartCard(context, cc, entry, lang),
              const SizedBox(height: 8),
              _calcCard(context, entry, lang),
            ]);
          },
        ),
      ),
    );
  }

  Widget _freshness(BuildContext c, Entry e, String lang) {
    final age = DateTime.now().difference(e.date).inDays;
    final stale = age > 14;
    final text = tr(c, 'updated').replaceAll('{d}', fmtDate(e.date, lang));
    final freq = tr(c, e.frequency == 'daily' ? 'daily' : 'weekly');
    return Card(
      color: stale ? Theme.of(c).colorScheme.errorContainer : Theme.of(c).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Icon(stale ? Icons.warning_amber : Icons.update, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('$text · $freq · ${e.source}', style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }

  Widget _priceCard(BuildContext c, Entry e, String f, String lang) {
    final v = e.prices[f]!;
    final p = e.prev?[f];
    Widget? chg;
    if (p != null) {
      final d = v - p;
      final flat = d.abs() < 0.0005;
      final col = flat ? Theme.of(c).hintColor : (d > 0 ? Colors.red : Colors.green);
      final cents = e.currency == 'USD' ? 'c' : 'ct';
      chg = Text('${flat ? '→' : d > 0 ? '▲' : '▼'} ${d > 0 ? '+' : ''}${fmtNum(d * 100, lang, 1)} $cents',
          style: TextStyle(color: col, fontWeight: FontWeight.w600));
    }
    return Card(
      child: Container(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: fuelColors[f]!, width: 5)), borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fuelName(c, f), style: const TextStyle(fontWeight: FontWeight.w600)),
              ?chg,
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${fmtMoney(v, e.currency, lang)} ${unitLabel(e)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            if (e.unit == 'gal') Text('≈ ${fmtMoney(e.perLitre(v), e.currency, lang)} /L', style: Theme.of(c).textTheme.bodySmall),
          ]),
        ]),
      ),
    );
  }

  Widget _chartCard(BuildContext c, String cc, Entry e, String lang) {
    if (_histCc != cc || _hist == null) {
      _histCc = cc;
      _hist = widget.api.historyAll(cc);
    }
    final fuels = fuelOrder.where(e.prices.containsKey).toList();
    if (!fuels.contains(_fuel)) _fuel = fuels.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr(c, 'trend'), style: Theme.of(c).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final f in fuels) ChoiceChip(label: Text(fuelName(c, f)), selected: _fuel == f, onSelected: (_) => setState(() => _fuel = f)),
            const SizedBox(width: 8),
            for (final m in [3, 12, 24]) ChoiceChip(label: Text(m < 12 ? '${m}M' : '${m ~/ 12}Y'), selected: _months == m, onSelected: (_) => setState(() => _months = m)),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: FutureBuilder<Map<String, Series>>(
              future: _hist,
              builder: (c, s) {
                final ser = s.data?[_fuel];
                if (ser == null || ser.points.length < 2) return const SizedBox();
                final last = ser.points.last.$1;
                final cut = DateTime(last.year, last.month - _months, last.day);
                final pts = ser.points.where((p) => !p.$1.isBefore(cut)).toList();
                if (pts.length < 2) return const SizedBox();
                final vals = pts.map((p) => ser.unit == 'gal' ? p.$2 : p.$2).toList();
                final lo = vals.reduce((a, b) => a < b ? a : b), hi = vals.reduce((a, b) => a > b ? a : b);
                final pad = ((hi - lo) * 0.15).clamp(0.01, 10.0);
                final col = fuelColors[_fuel]!;
                return LineChart(LineChartData(
                  minY: lo - pad,
                  maxY: hi + pad,
                  gridData: const FlGridData(drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44, interval: (hi - lo + 2 * pad) / 4, getTitlesWidget: (v, m) => Text(fmtNum(v, lang, 2), style: const TextStyle(fontSize: 10)))),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: (pts.length / 4).ceilToDouble(),
                        getTitlesWidget: (v, m) {
                          final i = v.toInt();
                          if (i < 0 || i >= pts.length) return const SizedBox();
                          return Padding(padding: const EdgeInsets.only(top: 4), child: Text(fmtDate(pts[i].$1, lang), style: const TextStyle(fontSize: 9)));
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => [
                        for (final t in spots) LineTooltipItem('${fmtDate(pts[t.spotIndex].$1, lang)}\n${fmtNum(t.y, lang)}', const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (var i = 0; i < pts.length; i++) FlSpot(i.toDouble(), pts[i].$2)],
                      isCurved: false,
                      color: col,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: col.withValues(alpha: 0.15)),
                    ),
                  ],
                ));
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _calcCard(BuildContext c, Entry e, String lang) {
    double num(TextEditingController t) => double.tryParse(t.text.replaceAll(',', '.')) ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr(c, 'calc'), style: Theme.of(c).textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _km, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr(c, 'distance'), border: const OutlineInputBorder()), onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _cons, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr(c, 'consumption'), border: const OutlineInputBorder()), onChanged: (_) => setState(() {}))),
          ]),
          const SizedBox(height: 8),
          for (final f in fuelOrder.where(e.prices.containsKey))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Expanded(child: Text(fuelName(c, f))),
                Text(fmtMoney(e.perLitre(e.prices[f]!) * num(_cons) * num(_km) / 100, e.currency, lang, 2), style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
        ]),
      ),
    );
  }
}
