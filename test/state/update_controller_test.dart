import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/core/update.dart';
import 'package:mp3_direct_cut/state/update_controller.dart';

import '../support/fake_updater.dart';

void main() {
  final release = Release(
    version: '0.0.3',
    archiveUrl: Uri.parse('https://example.com/a.tar.gz'),
    pageUrl: Uri.parse('https://example.com/r'),
  );

  ProviderContainer container(FakeUpdater updater, {bool installed = true}) {
    final c = ProviderContainer(overrides: [
      updaterProvider.overrideWithValue(updater),
      appInstallProvider.overrideWithValue(AppInstall(version: '0.0.2', dir: Directory('/opt/app'), installed: installed)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('a quiet check offers a newer release and stays silent otherwise', () async {
    for (final (newest, stage) in [(release, UpdateStage.available), (null, UpdateStage.idle)]) {
      final c = container(FakeUpdater(newest: newest));
      await c.read(updateProvider.notifier).check(quiet: true);
      expect(c.read(updateProvider).stage, stage);
    }
    final failing = container(FakeUpdater(error: const SocketException('offline')));
    await failing.read(updateProvider.notifier).check(quiet: true);
    expect(failing.read(updateProvider).stage, UpdateStage.idle);
  });

  test('a manual check says when the app is up to date or the check failed', () async {
    final same = container(FakeUpdater(
        newest: Release(version: '0.0.2', archiveUrl: release.archiveUrl, pageUrl: release.pageUrl)));
    await same.read(updateProvider.notifier).check();
    expect(same.read(updateProvider).stage, UpdateStage.upToDate);

    final failing = container(FakeUpdater(error: const SocketException('offline')));
    await failing.read(updateProvider.notifier).check();
    expect(failing.read(updateProvider).stage, UpdateStage.failed);
    expect(failing.read(updateProvider).error, contains('offline'));
  });

  test('install replaces the installed app and then offers a restart', () async {
    final updater = FakeUpdater(newest: release);
    final c = container(updater);
    await c.read(updateProvider.notifier).check();
    await c.read(updateProvider.notifier).install();
    expect(updater.installed, [('0.0.3', '/opt/app')]);
    expect(c.read(updateProvider).stage, UpdateStage.installed);
  });

  test('a failed install is reported', () async {
    final updater = FakeUpdater(newest: release, installError: const UpdateException('disk full'));
    final c = container(updater);
    await c.read(updateProvider.notifier).check();
    await c.read(updateProvider.notifier).install();
    expect(c.read(updateProvider).stage, UpdateStage.failed);
    expect(c.read(updateProvider).error, 'disk full');
  });

  test('a copy not installed by the installer is never replaced', () async {
    final updater = FakeUpdater(newest: release);
    final c = container(updater, installed: false);
    await c.read(updateProvider.notifier).check();
    await c.read(updateProvider.notifier).install();
    expect(updater.installed, isEmpty);
    expect(c.read(updateProvider).stage, UpdateStage.available);
  });

  test('AppInstall knows the installer location', () {
    final app = AppInstall.at(Directory('/home/u/.local/share/mp3-direct-cut'), {'HOME': '/home/u'});
    expect(app.installed, isTrue);
    expect(AppInstall.at(Directory('/home/u/dev/build/bundle'), {'HOME': '/home/u'}).installed, isFalse);
    expect(AppInstall.at(Directory('/x/mp3-direct-cut'), {'HOME': '/home/u', 'XDG_DATA_HOME': '/x'}).installed, isTrue);
  });
}
