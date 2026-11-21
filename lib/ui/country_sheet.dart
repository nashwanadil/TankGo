import 'package:material_ui/material_ui.dart';
import '../countries.dart';
import '../strings.dart';

Future<String?> pickCountry(BuildContext context) => showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _Sheet(),
    );

class _Sheet extends StatefulWidget {
  const _Sheet();
  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final list = countries.where((x) => x.name.toLowerCase().contains(_q.toLowerCase())).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom),
      child: Column(children: [
        TextField(
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: tr(context, 'search'), border: const OutlineInputBorder()),
          onChanged: (v) => setState(() => _q = v),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(children: [
            for (final x in list)
              ListTile(
                leading: Text(x.flag, style: const TextStyle(fontSize: 26)),
                title: Text(x.name),
                onTap: () => Navigator.pop(context, x.code),
              ),
          ]),
        ),
      ]),
    );
  }
}
