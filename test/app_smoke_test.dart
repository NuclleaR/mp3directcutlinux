import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/app.dart';

void main() {
  testWidgets('shows the open-folder button in Ukrainian and English', (t) async {
    for (final (locale, label) in [
      (const Locale('uk'), 'Відкрити теку'),
      (const Locale('en'), 'Open folder'),
    ]) {
      await t.pumpWidget(ProviderScope(key: UniqueKey(), child: App(locale: locale)));
      await t.pumpAndSettle();
      expect(find.text(label), findsOneWidget);
    }
  });
}
