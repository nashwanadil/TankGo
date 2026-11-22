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
  double _radius = 10;
  bool _byPrice = true;
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
      body: switch (_phase) {
        _Phase.locating => _busy(tx(context, 'stLocating')),
        _Phase.loading => _busy(tx(context, 'stLoading')),
        _Phase.needLocation => _locationHelp(context),
        _Phase.notCovered => _message(context, Icons.public_off, tx(context, 'stNotCovered'), key: const ValueKey('stNotCovered')),
        _Phase.error => _message(context, Icons.cloud_off, tx(context, 'stErr'), action: FilledButton(onPressed: _load, child: Text(tr(context, 'retry')))),
        _Phase.ready => _list(context),
      },
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
    Widget label(String t) => Padding(
      padding: const EdgeInsetsDirectional.only(end: 12),
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
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
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                label(tx(c, 'stRadius')),
                for (final r in const [5.0, 10.0, 25.0])
                  ChoiceChip(key: ValueKey('radius_${r.toInt()}'), label: Text('${r.toInt()} km'), selected: _radius == r, onSelected: (_) => setState(() => _radius = r)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                label('↕'),
                ChoiceChip(key: const ValueKey('sort_price'), avatar: const Icon(Icons.euro, size: 16), label: Text(tx(c, 'stSortPrice')), selected: _byPrice, onSelected: (_) => setState(() => _byPrice = true)),
                ChoiceChip(key: const ValueKey('sort_dist'), avatar: const Icon(Icons.near_me, size: 16), label: Text(tx(c, 'stSortDist')), selected: !_byPrice, onSelected: (_) => setState(() => _byPrice = false)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext c) {
    final lang = Localizations.localeOf(c).languageCode;
    final hits = nearbyStations(_stations, lat: _lat, lon: _lon, fuel: _fuel, radiusKm: _radius, byPrice: _byPrice);
    final best = cheapest(hits);
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
        for (final h in hits) _row(c, h, identical(h, best), today, lang),
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

  Widget _row(BuildContext c, Hit h, bool isBest, DateTime today, String lang) {
    final s = h.station;
    final old = s.date != null && DateUtils.dateOnly(s.date!).isBefore(today);
    final addr = [s.address, s.city].where((e) => e.isNotEmpty).join(', ');
    final dark = Theme.of(c).brightness == Brightness.dark;
    return Card(
      key: ValueKey('st_${s.id}'),
      shape: isBest
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(rCard),
              side: const BorderSide(color: positive, width: 2),
            )
          : _shape(c),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => widget.openUrl(navigationUri(s)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  if (isBest)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: dark ? gold : positive, borderRadius: BorderRadius.circular(rElement)),
                      child: Text(tx(c, 'stCheapest'), style: TextStyle(color: dark ? darkBrown : Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  Text(fmtMoney(h.price, 'EUR', lang), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                  if (old) Text(tx(c, 'stAsOf').replaceFirst('{d}', fmtShortDate(s.date!, lang)), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(c).colorScheme.error)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
