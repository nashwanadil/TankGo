import 'package:material_ui/material_ui.dart';

/// Selects the whole field content on tap so the user can type a new value directly.
void selectAll(TextEditingController c) => c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);

/// A numeric input styled like the list cards (icon, label, value on the trailing side).
class NumberRow extends StatelessWidget {
  const NumberRow({super.key, required this.icon, required this.label, required this.controller, required this.onChanged, this.suffix, this.color});
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? suffix;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final col = color ?? Theme.of(context).colorScheme.primary;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: col, width: 2),
      ),
      child: ListTile(
        leading: Icon(icon, color: col, size: 28),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 2),
        trailing: SizedBox(
          width: 96,
          child: TextField(
            controller: controller,
            textAlign: TextAlign.end,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            decoration: InputDecoration(isDense: true, border: InputBorder.none, suffixText: suffix),
            onTap: () => selectAll(controller),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
