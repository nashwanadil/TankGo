import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../location.dart';
import '../settings.dart';
import '../stations.dart';
import '../strings.dart';
import 'brand.dart';
import 'fmt.dart';
import 'home.dart' show fuelColor, fuelName;

typedef UrlOpener = Future<bool> Function(Uri url);

/// Complaints office for wrong station prices (required by the MTS-K licence).
const complaintsEmail = 'tankgo@nashwanadil.com';

Future<bool> _openExternal(Uri u) => launchUrl(u, mode: LaunchMode.externalApplication);

Uri navigationUri(Station s) => Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${s.lat},${s.lon}');

enum _Phase { locating, needLocation, loading, notCovered, error, ready }

/// Free feature: cheapest stations around the (coarse) device position.
/// Whole country files are downloaded and filtered locally, so the position is never sent anywhere.
class StationsPage extends StatefulWidget {
  const StationsPage({super.key, required this.api, required this.settings, this.fuel, this.location = const DeviceLocation(), this.openUrl = _openExternal});
  final Api api;
  final Settings settings;
  final String? fuel; // starting fuel (home screen selection); falls back to settings.fuel
  final LocationSource location;
  final UrlOpener openUrl;
  @override
  State<StationsPage> createState() => _StationsPageState();
}

class _StationsPageState extends State<StationsPage> {
  _Phase _phase = _Phase.locating;
  LocStatus _locStatus = LocStatus.denied;
  late String _fuel = stationFuels.contains(widget.fuel ?? widget.settings.fuel) ? (widget.fuel ?? widget.settings.fuel) : 'e95';
  double _radius = 5;
  StationSort _sort = StationSort.newest;
  double _lat = 0, _lon = 0;
  List<Station> _stations = const [];
  String _source = '';
  DateTime? _updated;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _phase = _Phase.locating);
    final loc = await widget.location.locate();
    if (!mounted) return;
    if (loc.status != LocStatus.ok) {
      setState(() {
        _locStatus = loc.status;
        _phase = _Phase.needLocation;
      });
      return;
    }
    _lat = loc.lat;
    _lon = loc.lon;
    var cands = countriesAt(_lat, _lon);
    if (cands.isEmpty) {
      setState(() => _phase = _Phase.notCovered);
      return;
    }
    setState(() => _phase = _Phase.loading);
    final index = await widget.api.stationIndex();
    if (!mounted) return;
    if (index != null) cands = cands.where(index.contains).toList();
    if (cands.isEmpty) {
      setState(() => _phase = _Phase.notCovered);
      return;
    }
    try {
      final files = await Future.wait([for (final cc in cands) widget.api.stations(cc)]);
      if (!mounted) return;
      setState(() {
        _stations = [for (final f in files) ...f.stations];
        _source = files.map((f) => f.source).where((s) => s.isNotEmpty).toSet().join(' · ');
        _updated = files.map((f) => DateTime.tryParse(f.updated)).whereType<DateTime>().fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
        _phase = _Phase.ready;
      });
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'stNear'))),
      body: Column(
        children: [
          _stamp(context),
          Expanded(
            child: switch (_phase) {
              _Phase.locating => _busy(tx(context, 'stLocating')),
              _Phase.loading => _busy(tx(context, 'stLoading')),
              _Phase.needLocation => _locationHelp(context),
              _Phase.notCovered => _message(context, Icons.public_off, tx(context, 'stNotCovered'), key: const ValueKey('stNotCovered')),
              _Phase.error => _message(context, Icons.cloud_off, tx(context, 'stErr'), action: FilledButton(onPressed: _load, child: Text(tr(context, 'retry')))),
              _Phase.ready => _list(context),
            },
          ),
        ],
      ),
    );
  }

  /// Stamp that states, on every state of this page, where the feature works (France and Spain only).
  Widget _stamp(BuildContext c) {
    final col = Theme.of(c).brightness == Brightness.dark ? gold : brand;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Center(
        child: Transform.rotate(
          angle: -0.035,
          child: Container(
            key: const ValueKey('stStamp'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: col, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.place_outlined, size: 18, color: col),
                const SizedBox(width: 6),
                Flexible(child: Text(tx(c, 'stCovered'), style: TextStyle(color: col, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.4))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _busy(String label) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(label)]),
  );

  Widget _message(BuildContext c, IconData icon, String text, {Widget? action, Key? key}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        key: key,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: gold),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          if (action != null) ...[const SizedBox(height: 20), action],
        ],
      ),
    ),
  );

  Widget _locationHelp(BuildContext c) {
    final blocked = _locStatus == LocStatus.deniedForever || _locStatus == LocStatus.serviceOff;
    final body = switch (_locStatus) {
      LocStatus.serviceOff => tx(c, 'stOffBody'),
      LocStatus.deniedForever => tx(c, 'stForeverBody'),
      LocStatus.error => tx(c, 'stLocErr'),
      _ => tx(c, 'stPermBody'),
    };
    return _message(
      c,
      Icons.location_off_outlined,
      '${_locStatus == LocStatus.denied ? '${tx(c, 'stPermTitle')}\n\n' : ''}$body',
      key: const ValueKey('stLocation'),
      action: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          if (blocked) FilledButton(onPressed: () => widget.location.openSettings(_locStatus), child: Text(tx(c, 'stSettings'))),
          blocked ? OutlinedButton(onPressed: _load, child: Text(tr(c, 'retry'))) : FilledButton(onPressed: _load, child: Text(tx(c, 'stAllow'))),
        ],
      ),
    );
  }

  ShapeBorder _shape(BuildContext c) => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(rCard),
    side: BorderSide(color: Theme.of(c).dividerColor.withValues(alpha: 0.4)),
  );

  Widget _controls(BuildContext c) {
    final col = fuelColor(c, _fuel);
    final segStyle = SegmentedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      selectedBackgroundColor: col.withValues(alpha: 0.28),
    );
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rCard),
        side: BorderSide(color: col, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final f in stationFuels)
                  ChoiceChip(
                    key: ValueKey('fuel_$f'),
                    label: Text(fuelName(c, f)),
                    selected: _fuel == f,
                    selectedColor: fuelColor(c, f).withValues(alpha: 0.3),
                    onSelected: (_) => setState(() => _fuel = f),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.radar, size: 20, color: col),
                const SizedBox(width: 8),
                Expanded(
                  child: SegmentedButton<double>(
                    showSelectedIcon: false,
                    style: segStyle,
                    segments: [for (final r in const [5.0, 10.0, 25.0]) ButtonSegment(value: r, label: Text('${r.toInt()} km', key: ValueKey('radius_${r.toInt()}'), maxLines: 1))],
                    selected: {_radius},
                    onSelectionChanged: (v) => setState(() => _radius = v.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<StationSort>(
              showSelectedIcon: false,
              style: segStyle,
              segments: [
                ButtonSegment(value: StationSort.price, icon: const Icon(Icons.sell_outlined, size: 16), label: FittedBox(fit: BoxFit.scaleDown, child: Text(tx(c, 'stSortPrice'), key: const ValueKey('sort_price'), maxLines: 1))),
                ButtonSegment(value: StationSort.distance, icon: const Icon(Icons.near_me_outlined, size: 16), label: FittedBox(fit: BoxFit.scaleDown, child: Text(tx(c, 'stSortDist'), key: const ValueKey('sort_dist'), maxLines: 1))),
                ButtonSegment(value: StationSort.newest, icon: const Icon(Icons.update, size: 16), label: FittedBox(fit: BoxFit.scaleDown, child: Text(tx(c, 'stSortNew'), key: const ValueKey('sort_new'), maxLines: 1))),
              ],
              selected: {_sort},
              onSelectionChanged: (v) => setState(() => _sort = v.first),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext c) {
    final lang = Localizations.localeOf(c).languageCode;
    final hits = nearbyStations(_stations, lat: _lat, lon: _lon, fuel: _fuel, radiusKm: _radius, sort: _sort);
    final best = cheapest(hits);
    final near = nearest(hits);
    final today = DateUtils.dateOnly(DateTime.now());
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _controls(c),
        const SizedBox(height: 4),
        if (hits.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(tx(c, 'stNone'), textAlign: TextAlign.center),
          ),
        for (final h in hits) _row(c, h, identical(h, best), identical(h, near), today, lang),
        const SizedBox(height: 12),
        Text(
          [
            if (_source.isNotEmpty) tx(c, 'stSource').replaceFirst('{s}', _source),
            if (_updated != null) tx(c, 'stAsOf').replaceFirst('{d}', fmtDate(_updated!.toLocal(), lang)),
          ].join(' · '),
          style: Theme.of(c).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(tx(c, 'stNote'), style: Theme.of(c).textTheme.bodySmall, textAlign: TextAlign.center),
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: Text(tx(c, 'stReport')),
            onPressed: () => _openExternal(Uri(
              scheme: 'mailto',
              path: complaintsEmail,
              query: 'subject=${Uri.encodeComponent('TankGo – ${tx(c, 'stReport')}')}',
            )),
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext c, Hit h, bool isBest, bool isNearest, DateTime today, String lang) {
    final s = h.station;
    final addr = [s.address, s.city].where((e) => e.isNotEmpty).join(', ');
    final dark = Theme.of(c).brightness == Brightness.dark;
    return Card(
      key: ValueKey('st_${s.id}'),
      margin: const EdgeInsets.symmetric(vertical: 2),
      shape: isBest
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(rCard),
              side: const BorderSide(color: positive, width: 2),
            )
          : isNearest
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(rCard),
              side: const BorderSide(color: brand, width: 2),
            )
          : _shape(c),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => widget.openUrl(navigationUri(s)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isBest || isNearest)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (isBest) _badge(tx(c, 'stCheapest'), dark ? gold : positive, dark ? darkBrown : Colors.white),
                            if (isNearest) _badge(tx(c, 'stNearest'), brand, Colors.white),
                          ],
                        ),
                      ),
                    Text(s.name.isEmpty ? s.city : s.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (addr.isNotEmpty) Text(addr, style: Theme.of(c).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('\u2066${fmtNum(h.km, lang, 1)} km\u2069', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(fmtMoney(h.price, 'EUR', lang), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                  if (s.date != null) _age(c, s, today, lang),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(rElement)),
    child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 11)),
  );

  /// Age of the price report under the price: under a day in green, yesterday neutral, older in red.
  /// With a time of day: minutes/hours; sources that only give the day show today/yesterday/days.
  Widget _age(BuildContext c, Station st, DateTime today, String lang) {
    final date = st.date!;
    final String text;
    Color? color;
    final diff = DateTime.now().difference(date);
    final days = st.timed ? diff.inDays : today.difference(DateUtils.dateOnly(date)).inDays;
    if (st.timed && diff.inHours < 24) {
      text = diff.inMinutes < 60 ? tx(c, 'stMinAgo').replaceFirst('{n}', '${diff.inMinutes < 1 ? 1 : diff.inMinutes}') : tx(c, 'stHoursAgo').replaceFirst('{n}', '${diff.inHours}');
      color = positive;
    } else if (days <= 0) {
      text = tx(c, 'stToday');
      color = positive;
    } else if (days == 1) {
      text = tx(c, 'stYesterday');
    } else {
      text = days < 14 ? tx(c, 'stDaysAgo').replaceFirst('{n}', '$days') : tx(c, 'stAsOf').replaceFirst('{d}', fmtShortDate(date.toLocal(), lang));
      color = Theme.of(c).colorScheme.error;
    }
    return Text(text, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color));
  }
}
