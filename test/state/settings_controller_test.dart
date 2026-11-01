import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/state/settings_controller.dart';

void main() {
  test('defaults: sort by name, 300 px panel', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final s = c.read(settingsProvider);
    expect([s.fileSort, s.panelWidth], [FileSort.name, 300]);
  });

  test('changes are saved and come back in the next session', () async {
    final store = MemorySettingsStore();
    final c = ProviderContainer(overrides: [settingsStoreProvider.overrideWithValue(store)]);
    c.read(settingsProvider.notifier)
      ..setFileSort(FileSort.number)
      ..setPanelWidth(420);
    await c.read(settingsProvider.notifier).flush();
    c.dispose();

    final next = ProviderContainer(overrides: [settingsStoreProvider.overrideWithValue(store)]);
    addTearDown(next.dispose);
    next.read(settingsProvider);
    await pumpEventQueue();
    final s = next.read(settingsProvider);
    expect([s.fileSort, s.panelWidth], [FileSort.number, 420]);
  });

  test('file store: saved settings load back; a missing or broken file gives defaults', () async {
    final dir = Directory.systemTemp.createTempSync('settings');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/mp3-direct-cut/settings.json');
    final store = FileSettingsStore(file);

    expect((await store.load()).fileSort, FileSort.name);
    await store.save(const AppSettings(fileSort: FileSort.number, panelWidth: 410));
    final back = await store.load();
    expect([back.fileSort, back.panelWidth], [FileSort.number, 410]);

    file.writeAsStringSync('{oops');
    final broken = await store.load();
    expect([broken.fileSort, broken.panelWidth], [FileSort.name, 300]);
  });

  test('file store lives in the XDG config dir', () {
    expect(FileSettingsStore.forUser({'XDG_CONFIG_HOME': '/x', 'HOME': '/h'}).file.path,
        '/x/mp3-direct-cut/settings.json');
    expect(FileSettingsStore.forUser({'HOME': '/h'}).file.path, '/h/.config/mp3-direct-cut/settings.json');
  });
}
