import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/app.dart';
import 'package:mp3_direct_cut/audio/audio_engine.dart';
import 'package:mp3_direct_cut/state/apply_controller.dart';
import 'package:mp3_direct_cut/state/folder_controller.dart';
import 'package:mp3_direct_cut/state/queue_controller.dart';
import 'package:mp3_direct_cut/state/queue_entry.dart';
import 'package:mp3_direct_cut/state/queue_store.dart';
import 'package:mp3_direct_cut/state/selection_controller.dart';

import '../support/fake_analysis.dart';
import '../support/fake_audio_engine.dart';
import '../support/pump.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('panel');
    File('test/fixtures/cbr_stereo_44k.mp3').copySync('${dir.path}/a.mp3');
    File('test/fixtures/plain_cbr.mp3').copySync('${dir.path}/b.mp3');
    File('${dir.path}/broken.mp3').writeAsStringSync('0123456789');
    Directory('${dir.path}/sub').createSync();
    File('test/fixtures/plain_cbr.mp3').copySync('${dir.path}/sub/inner.mp3');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  void seedQueue(Map<String, Object?> entry) {
    File('${dir.path}/.mp3directcut-queue.json').writeAsStringSync(jsonEncode({
      'version': 1,
      'entries': {'a.mp3': entry},
    }));
  }

  Map<String, Object?> entryJson({required int mtimeMs, String status = 'done'}) => {
        'size': File('${dir.path}/a.mp3').lengthSync(),
        'mtimeMs': mtimeMs,
        'deletes': [
          [10, 20],
          [40, 50],
        ],
        'splits': [100],
        'name': null,
        'partNames': <String, String>{},
        'status': status,
        'ownOutputs': <Object>[],
        'results': <Object>[],
        'obsolete': <Object>[],
      };

  Future<ProviderContainer> openApp(WidgetTester t, {List<Override> extra = const []}) async {
    final c = ProviderContainer(overrides: [
      ...extra,
      folderPickerProvider.overrideWithValue(() async => dir.path),
      probeProvider.overrideWith((ref, path) async => !path.endsWith('broken.mp3')),
      audioEngineProvider.overrideWithValue(FakeAudioEngine()),
      fileAnalysisProvider.overrideWith((ref, path) async => fakeAnalysis(path: path)),
    ]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const App(locale: Locale('uk'))));
    await t.tap(find.text('Відкрити теку'));
    await pumpUntil(t, () => c.read(folderProvider) != null && c.read(queueProvider).sources.isNotEmpty);
    return c;
  }

  testWidgets('opens a folder and lists only its top-level mp3 files', (t) async {
    await openApp(t);
    for (final n in ['a.mp3', 'b.mp3', 'broken.mp3']) {
      expect(find.text(n), findsOneWidget);
    }
    expect(find.text('inner.mp3'), findsNothing);
  });

  testWidgets('broken mp3 is greyed and not selectable', (t) async {
    final c = await openApp(t);
    await t.tap(find.text('broken.mp3'));
    await t.pump();
    expect(c.read(selectedFileProvider), isNull);
    await t.tap(find.text('a.mp3'));
    await t.pump();
    expect(c.read(selectedFileProvider), 'a.mp3');
  });

  testWidgets('row shows queue counts and status', (t) async {
    seedQueue(entryJson(mtimeMs: File('${dir.path}/a.mp3').lastModifiedSync().millisecondsSinceEpoch));
    await openApp(t);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Готово'), findsOneWidget);
  });

  testWidgets('Apply disabled with nothing pending', (t) async {
    await openApp(t);
    final button = t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Застосувати'));
    expect(button.onPressed, isNull);
  });

  testWidgets('stale row clears with the button', (t) async {
    seedQueue(entryJson(mtimeMs: 1, status: 'pending'));
    final c = await openApp(t);
    expect(find.text('Файл-джерело змінився'), findsOneWidget);
    await t.tap(find.byTooltip('Позначити перевіреним'));
    await t.pump();
    expect(c.read(queueProvider).isStale('a.mp3'), isFalse);
    expect(find.text('Файл-джерело змінився'), findsNothing);
    await t.runAsync(() => c.read(queueProvider.notifier).flush());
  });

  testWidgets('Open folder is disabled while Apply runs', (t) async {
    final c = await openApp(t, extra: [applyProvider.overrideWith(_ApplyStub.new)]);
    (c.read(applyProvider.notifier) as _ApplyStub).start();
    await t.pump();
    final button = t.widget<ButtonStyleButton>(
        find.ancestor(of: find.text('Відкрити теку'), matching: find.bySubtype<ButtonStyleButton>()));
    expect(button.onPressed, isNull);
  });

  testWidgets('Clear queue is disabled with nothing pending', (t) async {
    await openApp(t);
    final button = t.widget<ButtonStyleButton>(
        find.ancestor(of: find.text('Очистити чергу'), matching: find.bySubtype<ButtonStyleButton>()));
    expect(button.onPressed, isNull);
  });

  testWidgets('Clear queue asks first, then drops unfinished marks', (t) async {
    final mtime = File('${dir.path}/a.mp3').lastModifiedSync().millisecondsSinceEpoch;
    seedQueue(entryJson(mtimeMs: mtime, status: 'pending'));
    final c = await openApp(t);
    await t.tap(find.text('Очистити чергу'));
    await t.pumpAndSettle();
    expect(find.text('Очистити чергу?'), findsOneWidget);
    await t.tap(find.text('Скасувати'));
    await t.pumpAndSettle();
    expect(c.read(queueProvider).entries['a.mp3'], isNotNull);
    await t.tap(find.text('Очистити чергу'));
    await t.pumpAndSettle();
    await t.tap(find.text('Очистити'));
    await t.pump();
    // Save before the debounce timer fires in fake time, where its file write never ends.
    await t.runAsync(() => c.read(queueProvider.notifier).flush());
    await t.pumpAndSettle();
    expect(c.read(queueProvider).entries['a.mp3'], isNull);
  });

  testWidgets('a failed queue save is shown', (t) async {
    final c = await openApp(t, extra: [queueStoreProvider.overrideWithValue(_FailingStore())]);
    c.read(queueProvider.notifier).setOutputName('a.mp3', 'Ріпка');
    await t.runAsync(() => c.read(queueProvider.notifier).flush());
    await t.pump();
    expect(find.textContaining('Не вдалося зберегти чергу'), findsOneWidget);
  });
}

class _FailingStore extends QueueStore {
  @override
  Future<void> save(Directory folder, Map<String, QueueEntry> entries) async =>
      throw const FileSystemException('No space left on device');
}

class _ApplyStub extends ApplyController {
  void start() => state = const ApplyState(running: true);
}
