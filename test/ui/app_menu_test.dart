import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/app.dart';
import 'package:mp3_direct_cut/audio/audio_engine.dart';
import 'package:mp3_direct_cut/core/update.dart';
import 'package:mp3_direct_cut/state/update_controller.dart';

import '../support/fake_audio_engine.dart';
import '../support/fake_updater.dart';

void main() {
  const channel = MethodChannel('mp3_direct_cut/menu');
  final release = Release(
    version: '0.0.3',
    archiveUrl: Uri.parse('https://example.com/a.tar.gz'),
    pageUrl: Uri.parse('https://example.com/r'),
  );

  Future<ProviderContainer> start(WidgetTester t, FakeUpdater updater, {bool installed = true}) async {
    final c = ProviderContainer(overrides: [
      updaterProvider.overrideWithValue(updater),
      appInstallProvider.overrideWithValue(AppInstall(version: '0.0.2', dir: Directory('/opt/app'), installed: installed)),
      audioEngineProvider.overrideWithValue(FakeAudioEngine()),
    ]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const App(locale: Locale('uk'))));
    await t.pumpAndSettle();
    return c;
  }

  Future<void> choose(WidgetTester t, String id) async {
    await t.binding.defaultBinaryMessenger.handlePlatformMessage(
        channel.name, const StandardMethodCodec().encodeMethodCall(MethodCall('select', id)), (_) {});
    await t.pumpAndSettle();
  }

  Finder inDialog(Finder f) => find.descendant(of: find.byType(AlertDialog), matching: f);

  testWidgets('the title bar menu gets its items in the app language', (t) async {
    final calls = <MethodCall>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    await start(t, FakeUpdater());
    expect(calls.single.method, 'setItems');
    expect(calls.single.arguments, [
      ['about', 'Про програму'],
      ['check-updates', 'Перевірити оновлення'],
    ]);
  });

  testWidgets('About shows the version', (t) async {
    await start(t, FakeUpdater());
    await choose(t, 'about');
    expect(find.text('MP3 Direct Cut'), findsWidgets);
    expect(find.text('0.0.2'), findsOneWidget);
  });

  testWidgets('checking finds nothing newer', (t) async {
    await start(t, FakeUpdater());
    await choose(t, 'check-updates');
    expect(find.text('У тебе найновіша версія, 0.0.2.'), findsOneWidget);
  });

  testWidgets('checking finds a release, installs it and restarts', (t) async {
    final updater = FakeUpdater(newest: release);
    await start(t, updater);
    await choose(t, 'check-updates');
    expect(find.text('Вийшла версія 0.0.3, у тебе 0.0.2.'), findsOneWidget);

    await t.tap(inDialog(find.text('Оновити')));
    await t.pumpAndSettle();
    expect(updater.installed, [('0.0.3', '/opt/app')]);
    expect(find.text('Версію 0.0.3 встановлено. Перезапустити зараз?'), findsOneWidget);

    await t.tap(inDialog(find.text('Перезапустити')));
    await t.pumpAndSettle();
    expect(updater.restarts, 1);
  });

  testWidgets('a copy not installed by the installer only links to the release', (t) async {
    await start(t, FakeUpdater(newest: release), installed: false);
    await choose(t, 'check-updates');
    expect(inDialog(find.text('Оновити')), findsNothing);
    expect(inDialog(find.text('Відкрити реліз')), findsOneWidget);
  });

  testWidgets('the startup check shows a banner until dismissed', (t) async {
    await start(t, FakeUpdater(newest: release));
    expect(find.text('Вийшла версія 0.0.3'), findsOneWidget);
    await t.tap(find.text('Пізніше'));
    await t.pumpAndSettle();
    expect(find.text('Вийшла версія 0.0.3'), findsNothing);
  });

  testWidgets('the startup check stays silent when nothing is newer', (t) async {
    await start(t, FakeUpdater());
    expect(find.textContaining('Вийшла версія'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
