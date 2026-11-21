import 'package:intl/intl.dart';

import '../data.dart';

String fmtNum(double v, String lang, [int d = 3]) {
  if (lang == 'ku') lang = 'ar';
  try {
    return NumberFormat.decimalPatternDigits(locale: lang, decimalDigits: d).format(v);
  } catch (_) {
    return v.toStringAsFixed(d);
  }
}

String fmtDate(DateTime d, String lang) {
  if (lang == 'ku') lang = 'ar';
  try {
    return DateFormat.yMMMd(lang).format(d);
  } catch (_) {
    return d.toIso8601String().substring(0, 10);
  }
}

String fmtMoney(double v, String cur, String lang, [int d = 3]) {
  final n = fmtNum(v, lang, d);
  return cur == 'USD' ? '\$$n' : '$n €';
}

String unitLabel(Entry e) => e.unit == 'gal' ? '/gal' : '/L';
