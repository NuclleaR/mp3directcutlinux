import 'package:flutter_test/flutter_test.dart';

/// Lets real I/O started by the widget tree finish: alternates real waits with pumps
/// until [done] is true.
Future<void> pumpUntil(WidgetTester t, bool Function() done, {int tries = 100}) async {
  for (var i = 0; i < tries && !done(); i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pump();
  }
  expect(done(), isTrue, reason: 'condition not reached');
  await t.pump();
}
