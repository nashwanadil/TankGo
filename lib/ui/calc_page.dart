import 'package:material_ui/material_ui.dart';

import '../data.dart';
import '../strings.dart';
import 'fmt.dart';
import 'number_row.dart';
import 'home.dart' show fuelColor, fuelName, fuelOrder;

class CalcPage extends StatefulWidget {
  const CalcPage({super.key, required this.entry});
  final Entry entry;
  @override
  State<CalcPage> createState() => _CalcPageState();
}

class _CalcPageState extends State<CalcPage> {
  final _km = TextEditingController(text: '100');
  final _cons = TextEditingController(text: '6.5');

  @override
  void dispose() {
    _km.dispose();
    _cons.dispose();
    super.dispose();
  }

  double _n(TextEditingController t) => double.tryParse(t.text.replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final lang = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'calc'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NumberRow(icon: Icons.straighten, label: tr(context, 'distance'), controller: _km, onChanged: (_) => setState(() {})),
          NumberRow(icon: Icons.speed, label: tr(context, 'consumption'), controller: _cons, onChanged: (_) => setState(() {})),
          const SizedBox(height: 8),
          for (final f in fuelOrder.where(e.prices.containsKey))
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: fuelColor(context, f), width: 1.5),
              ),
              child: ListTile(
                leading: Icon(Icons.local_gas_station, color: fuelColor(context, f)),
                title: Text(fuelName(context, f), style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${fmtMoney(e.perLitre(e.prices[f]!), e.currency, lang)} /L'),
                trailing: Text(fmtMoney(e.perLitre(e.prices[f]!) * _n(_cons) * _n(_km) / 100, e.currency, lang, 2), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ),
            ),
        ],
      ),
    );
  }
}
