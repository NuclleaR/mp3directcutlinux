import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/state/editor_controller.dart';
import 'package:mp3_direct_cut/ui/editor/waveform_view.dart';
import 'package:mp3_direct_cut/ui/theme/cut_palette.dart';

import '../../support/fake_analysis.dart';

void main() {
  const fd = 1152 / 44100;
  final analysis = fakeAnalysis();

  Future<(ProviderContainer, List<double>)> pump(WidgetTester t) async {
    t.view
      ..physicalSize = const Size(1200, 600)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(editorProvider.notifier).reset('a.mp3', analysis);
    final seeks = <double>[];
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: CutPalette.light.toTheme(Brightness.light),
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 1000,
            child: WaveformView(analysis: analysis, playhead: () => 0, onSeek: seeks.add),
          ),
        ),
      ),
    ));
    return (c, seeks);
  }

  // The view starts at 0 and shows the whole file, so x px ≈ frame (x · 1000 / 1000).
  Offset at(double x) => Offset(x, 120);
  int frameOf(double seconds) => (seconds / fd).round();

  Future<void> drag(WidgetTester t, double from, double to) async {
    final g = await t.startGesture(at(from), kind: PointerDeviceKind.mouse);
    await g.moveTo(at((from + to) / 2));
    await g.moveTo(at(to));
    await g.up();
    await t.pump();
  }

  testWidgets('drag selects and snaps to silence', (t) async {
    final (c, _) = await pump(t);
    await drag(t, 100, 395);
    final s = c.read(editorProvider).selection!;
    expect(frameOf(s.$1), 100);
    expect(frameOf(s.$2), inInclusiveRange(400, 410));
  });

  testWidgets('without snap a new selection lands on frame boundaries', (t) async {
    final (c, _) = await pump(t);
    c.read(editorProvider.notifier).toggleSnap();
    await drag(t, 100, 395);
    final s = c.read(editorProvider).selection!;
    expect([frameOf(s.$1), frameOf(s.$2)], [100, 395]);
  });

  testWidgets('click sets cursor and clears selection', (t) async {
    final (c, seeks) = await pump(t);
    c.read(editorProvider.notifier).setSelection((100 * fd, 200 * fd));
    await t.tapAt(at(500), kind: PointerDeviceKind.mouse);
    await t.pump();
    expect(c.read(editorProvider).selection, isNull);
    expect(frameOf(c.read(editorProvider).cursor), 500);
    expect(frameOf(seeks.single), 500);
  });

  testWidgets('dragging an edge adjusts the selection', (t) async {
    final (c, _) = await pump(t);
    c.read(editorProvider.notifier).setSelection((100 * fd, 300 * fd));
    await t.pump();
    await drag(t, 302, 350);
    final s = c.read(editorProvider).selection!;
    expect([frameOf(s.$1), frameOf(s.$2)], [100, 350]);
  });

  testWidgets('wheel zooms around the pointer', (t) async {
    final (c, _) = await pump(t);
    final before = c.read(editorProvider).view;
    final tUnder = before.xToT(500, 1000);
    final pointer = TestPointer(1, PointerDeviceKind.mouse)..hover(at(500));
    await t.sendEventToBinding(pointer.scroll(const Offset(0, -100)));
    await t.pump();
    final after = c.read(editorProvider).view;
    expect(after.span, lessThan(before.span));
    expect(after.xToT(500, 1000), closeTo(tUnder, 1e-6));
  });
}
