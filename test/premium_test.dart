import 'package:flutter_test/flutter_test.dart';
import 'package:fuelprices/premium.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('remote switch unlocks Premium without a purchase, and can be switched off again', () async {
    SharedPreferences.setMockInitialValues({});
    final p = Premium(await SharedPreferences.getInstance(), billing: false);
    var notified = 0;
    p.addListener(() => notified++);
    expect(p.isPremium, false);
    await p.setRemoteFree(true);
    expect(p.isPremium, true);
    expect(p.lifetime, false); // not a purchase
    await p.setRemoteFree(true); // no change: no extra notification
    expect(notified, 1);
    await p.setRemoteFree(false);
    expect(p.isPremium, false);
    // a real purchase is unaffected by the switch
    await p.grant(idLife, DateTime.now());
    await p.setRemoteFree(false);
    expect(p.isPremium, true);
  });
}
