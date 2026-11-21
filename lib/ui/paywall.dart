import 'package:material_ui/material_ui.dart';
import '../premium.dart';
import '../strings.dart';
import 'brand.dart';

Future<void> showPaywall(BuildContext context, Premium premium) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _Paywall(premium),
    );

class _Paywall extends StatelessWidget {
  const _Paywall(this.premium);
  final Premium premium;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: premium,
      builder: (context, _) {
        final t = Theme.of(context);
        if (premium.isPremium) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.workspace_premium, size: 56, color: gold),
              const SizedBox(height: 12),
              Text(tx(context, 'active'), style: t.textTheme.titleLarge),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr(context, 'ok'))),
            ]),
          );
        }
        final plans = [
          (idYear, 'planYear', 'planYearSub', true),
          (idLife, 'planLife', 'planLifeSub', false),
          (idTrip, 'planTrip', 'planTripSub', false),
        ];
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.workspace_premium, size: 48, color: gold),
            const SizedBox(height: 8),
            Text(tx(context, 'pwTitle'), style: t.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(tx(context, 'pwSub'), textAlign: TextAlign.center),
            const SizedBox(height: 14),
            for (final k in const ['f1', 'f2', 'f3', 'f4'])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [const Icon(Icons.check_circle, size: 20, color: gold), const SizedBox(width: 10), Expanded(child: Text(tx(context, k)))]),
              ),
            const SizedBox(height: 14),
            for (final (id, title, sub, best) in plans)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: best ? gold : t.dividerColor, width: best ? 2 : 1)),
                child: ListTile(
                  title: Text(tx(context, title), style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(tx(context, sub)),
                  trailing: Text(premium.product(id)?.price ?? '—', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  enabled: premium.product(id) != null && !premium.busy,
                  onTap: () => premium.buy(id),
                ),
              ),
            if (premium.busy) const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
            if (!premium.storeReady || premium.products.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(tx(context, premium.storeReady ? 'noPlans' : 'storeOff'), textAlign: TextAlign.center, style: TextStyle(color: t.colorScheme.error)),
              ),
            if (premium.error != null && premium.storeReady) Text(premium.error!, textAlign: TextAlign.center, style: TextStyle(color: t.colorScheme.error, fontSize: 12)),
            TextButton(onPressed: premium.storeReady ? premium.restore : null, child: Text(tx(context, 'restore'))),
            if (premiumDebug) TextButton(onPressed: () => premium.grant(idLife, DateTime.now()), child: const Text('DEBUG unlock')),
            Text(tx(context, 'legal'), style: t.textTheme.bodySmall, textAlign: TextAlign.center),
          ]),
        );
      },
    );
  }
}
