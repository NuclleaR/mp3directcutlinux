import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/app.dart';
import 'package:mp3_direct_cut/audio/audio_engine.dart';
import 'package:mp3_direct_cut/core/frame_range.dart';
import 'package:mp3_direct_cut/state/editor_controller.dart';
import 'package:mp3_direct_cut/state/folder_controller.dart';
import 'package:mp3_direct_cut/state/playback_controller.dart';
import 'package:mp3_direct_cut/state/queue_controller.dart';
import 'package:mp3_direct_cut/state/queue_entry.dart';
import 'package:mp3_direct_cut/state/selection_controller.dart';
import 'package:mp3_direct_cut/ui/editor/view_window.dart';

import '../../support/fake_analysis.dart';
import '../../support/fake_audio_engine.dart';
import '../../support/pump.dart';

void main() {
  const fd = 1152 / 44100;
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('pane');
    File('test/fixtures/plain_cbr.mp3').copySync('${dir.path}/a.mp3');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<ProviderContainer> open(WidgetTester t) async {
    t.view
      ..physicalSize = const Size(1400, 1000)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final engine = FakeAudioEngine();
    final c = ProviderContainer(overrides: [
      audioEngineProvider.overrideWithValue(engine),
      fileAnalysisProvider.overrideWith((ref, path) async => fakeAnalysis(path: path)),
      probeProvider.overrideWith((ref, path) async => true),
    ]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const App(locale: Locale('uk'))));
    await t.runAsync(() => c.read(folderProvider.notifier).open(dir.path));
    c.read(selectedFileProvider.notifier).select('a.mp3');
    await pumpUntil(t, () => c.read(editorProvider).fileName == 'a.mp3');
    await t.pump();
    return c;
  }

  QueueEntry? entry(ProviderContainer c) => c.read(queueProvider).entries['a.mp3'];

  Future<void> key(WidgetTester t, LogicalKeyboardKey k, PhysicalKeyboardKey p) =>
      t.sendKeyEvent(k, physicalKey: p);

  Future<void> finish(WidgetTester t, ProviderContainer c) =>
      t.runAsync(() => c.read(queueProvider.notifier).flush());

  testWidgets('select + Del adds a delete and clears the selection', (t) async {
    final c = await open(t);
    c.read(editorProvider.notifier).setSelection((100 * fd, 200 * fd));
    await t.pump();
    await key(t, LogicalKeyboardKey.delete, PhysicalKeyboardKey.delete);
    await t.pump();
    expect(entry(c)!.deletes, const [FrameRange(100, 200)]);
    expect(c.read(editorProvider).selection, isNull);
    expect(find.text('Повернути'), findsOneWidget);
    await finish(t, c);
  });

  testWidgets('S adds a split at the playhead and shows the parts list', (t) async {
    final c = await open(t);
    // Clicked at frame 100 earlier, then listened on to frame 500.
    await c.read(playbackProvider.notifier).seek(100 * fd);
    (c.read(audioEngineProvider) as FakeAudioEngine).position = 500 * fd;
    await key(t, LogicalKeyboardKey.keyS, PhysicalKeyboardKey.keyS);
    await t.pump();
    expect(entry(c)!.splits, [500]);
    expect(find.text('Частини'), findsOneWidget);
    expect(find.byKey(const ValueKey('part-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('part-500')), findsOneWidget);
    await finish(t, c);
  });

  testWidgets('part name is saved for its anchor', (t) async {
    final c = await open(t);
    c.read(queueProvider.notifier).addSplit('a.mp3', 500, 1000);
    await t.pump();
    await t.enterText(find.widgetWithText(TextField, 'a part 2'), 'Ріпка');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(entry(c)!.partNames, {500: 'Ріпка'});
    await finish(t, c);
  });

  testWidgets('the file title can be selected for copying', (t) async {
    await open(t);
    expect(find.widgetWithText(SelectableText, 'a.mp3'), findsOneWidget);
  });

  String fieldText(WidgetTester t, Key key) =>
      t.widget<TextField>(find.descendant(of: find.byKey(key), matching: find.byType(TextField))).controller!.text;

  testWidgets('name fields start with the default names', (t) async {
    final c = await open(t);
    expect(fieldText(t, const ValueKey('output-name')), 'a');
    c.read(queueProvider.notifier).addSplit('a.mp3', 500, 1000);
    await t.pump();
    expect(fieldText(t, const ValueKey('part-0')), 'a part 1');
    expect(fieldText(t, const ValueKey('part-500')), 'a part 2');
    await finish(t, c);
  });

  testWidgets('a name equal to the default, or cleared, stores no custom name', (t) async {
    final c = await open(t);
    final field = find.descendant(of: find.byKey(const ValueKey('output-name')), matching: find.byType(TextField));
    await t.enterText(field, 'Ріпка');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(entry(c)!.outputName, 'Ріпка');
    await t.enterText(field, 'a');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(entry(c), isNull);
    await t.enterText(field, 'Ріпка');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.enterText(field, '');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(entry(c), isNull);
    await finish(t, c);
  });

  testWidgets('Ctrl+Z undoes the last mark', (t) async {
    final c = await open(t);
    c.read(editorProvider.notifier).setSelection((100 * fd, 200 * fd));
    await key(t, LogicalKeyboardKey.delete, PhysicalKeyboardKey.delete);
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft, physicalKey: PhysicalKeyboardKey.controlLeft);
    await key(t, LogicalKeyboardKey.keyZ, PhysicalKeyboardKey.keyZ);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft, physicalKey: PhysicalKeyboardKey.controlLeft);
    await t.pump();
    expect(entry(c), isNull);
    await finish(t, c);
  });

  testWidgets('typing 0 and S in a name field does not trigger shortcuts', (t) async {
    final c = await open(t);
    c.read(editorProvider.notifier).setView(const ViewWindow(0, 5));
    await t.pump();
    await t.tap(find.byType(TextField).first);
    await t.pump();
    await key(t, LogicalKeyboardKey.digit0, PhysicalKeyboardKey.digit0);
    await key(t, LogicalKeyboardKey.keyS, PhysicalKeyboardKey.keyS);
    await t.pump();
    expect(c.read(editorProvider).view.span, 5);
    expect(entry(c), isNull);
  });

  testWidgets('totals show before and after', (t) async {
    final c = await open(t);
    expect(find.text('Було 0:26 · стане 0:26'), findsOneWidget);
    c.read(queueProvider.notifier).addDelete('a.mp3', const FrameRange(100, 200));
    await t.pump();
    expect(find.text('Було 0:26 · стане 0:23'), findsOneWidget);
    await finish(t, c);
  });

  testWidgets('Restore removes a delete', (t) async {
    final c = await open(t);
    c.read(queueProvider.notifier).addDelete('a.mp3', const FrameRange(100, 200));
    await t.pump();
    await t.tap(find.text('Повернути'));
    await t.pump();
    expect(entry(c), isNull);
    await finish(t, c);
  });
}
