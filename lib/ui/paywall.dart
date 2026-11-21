import 'package:material_ui/material_ui.dart';

import '../premium.dart';
import '../strings.dart';
import 'brand.dart';

Future<void> showPaywall(BuildContext context, Premium premium) =>
    showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, backgroundColor: Colors.transparent, builder: (_) => _Paywall(premium));

class _Paywall extends StatelessWidget {
  const _Paywall(this.premium);
  final Premium premium;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: premium,
      builder: (context, _) {
        final t = Theme.of(context);
        final active = premium.isPremium;
        final plans = [(idYear, 'planYear', 'planYearSub', true), (idLife, 'planLife', 'planLifeSub', false), (idTrip, 'planTrip', 'planTripSub', false)];
        return Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [brandLight, brandDark, brandDeep]),
            border: Border(top: BorderSide(color: gold, width: 2)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: cream),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: gold.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.2),
                        border: Border.all(color: gold, width: 2),
                        boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.45), blurRadius: 24)],
                      ),
                      child: const Icon(Icons.workspace_premium, size: 44, color: gold),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    tx(context, active ? 'active' : 'pwTitle'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  if (!active) ...[
                    const SizedBox(height: 6),
                    Text(tx(context, 'pwSub'), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    for (final k in const ['f1', 'f2', 'f3', 'f4'])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 20, color: gold),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(tx(context, k), style: const TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    for (final (id, title, sub, best) in plans) _plan(context, id, title, sub, best),
                    if (premium.busy)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: LinearProgressIndicator(color: gold),
                      ),
                    if (!premium.storeReady || premium.products.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          tx(context, premium.storeReady ? 'noPlans' : 'storeOff'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: riseSoft),
                        ),
                      ),
                    if (premium.error != null && premium.storeReady)
                      Text(
                        premium.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: riseSoft, fontSize: 12),
                      ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: gold),
                      onPressed: premium.storeReady ? premium.restore : null,
                      child: Text(tx(context, 'restore')),
                    ),
                    if (premiumDebug)
                      TextButton(
                        onPressed: () => premium.grant(idLife, DateTime.now()),
                        child: const Text('DEBUG unlock', style: TextStyle(color: gold)),
                      ),
                    Text(
                      tx(context, 'legal'),
                      style: t.textTheme.bodySmall?.copyWith(color: cream.withValues(alpha: 0.7)),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: darkBrown),
                      onPressed: () => Navigator.pop(context),
                      child: Text(tr(context, 'ok')),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _plan(BuildContext context, String id, String title, String sub, bool best) {
    final p = premium.product(id);
    final enabled = p != null && !premium.busy;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: best ? gold.withValues(alpha: 0.16) : Colors.black.withValues(alpha: 0.22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: best ? gold : cream.withValues(alpha: 0.25), width: best ? 2 : 1),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: enabled ? () => premium.buy(id) : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx(context, title),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
                          ),
                          const SizedBox(height: 2),
                          Text(tx(context, sub), style: TextStyle(color: cream.withValues(alpha: 0.8), fontSize: 12.5)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      p?.price ?? '—',
                      style: TextStyle(color: best ? gold : Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (best)
            PositionedDirectional(
              top: -10,
              end: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  tx(context, 'best'),
                  style: const TextStyle(color: darkBrown, fontWeight: FontWeight.w800, fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
