import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/audio/audio_engine.dart';
import 'package:mp3_direct_cut/core/frame_range.dart';
import 'package:mp3_direct_cut/state/editor_controller.dart';
import 'package:mp3_direct_cut/state/playback_controller.dart';
import 'package:mp3_direct_cut/state/queue_controller.dart';
import 'package:mp3_direct_cut/ui/editor/view_window.dart';

import '../support/fake_analysis.dart';
import '../support/fake_audio_engine.dart';

void main() {
  const fd = 1152 / 44100;
  late FakeAudioEngine engine;
  late ProviderContainer c;

  setUp(() {
    engine = FakeAudioEngine();
    c = ProviderContainer(overrides: [audioEngineProvider.overrideWithValue(engine)]);
    c.read(editorProvider.notifier).reset('a.mp3', fakeAnalysis());
  });
  tearDown(() => c.dispose());

  PlaybackController p() => c.read(playbackProvider.notifier);

  test('skipTarget', () {
    expect(skipTarget(5.0, [(4.0, 6.0)]), 6.0);
    expect(skipTarget(3.995, [(4.0, 6.0)]), 6.0);
    expect(skipTarget(6.0, [(4.0, 6.0)]), isNull);
    expect(skipTarget(3.9, [(4.0, 6.0)]), isNull);
  });

  test('playing skips deletes', () async {
    c.read(queueProvider.notifier).addDelete('a.mp3', FrameRange((4 / fd).round(), (6 / fd).round()));
    await p().togglePlay();
    engine.position = 4.5;
    p().tick();
    expect(engine.seeks.single, closeTo(6, fd));
  });

  test('nothing happens while paused', () {
    c.read(queueProvider.notifier).addDelete('a.mp3', FrameRange((4 / fd).round(), (6 / fd).round()));
    engine.position = 4.5;
    p().tick();
    expect(engine.seeks, isEmpty);
  });

  test('listenJoin plays a−2..b+2 skipping [a, b] and stops', () async {
    await p().listenJoin(10, 12);
    expect(engine.seeks, [8]);
    expect(engine.playing, isTrue);
    engine.position = 11;
    p().tick();
    expect(engine.seeks.last, 12);
    engine.position = 14.05;
    p().tick();
    expect(engine.playing, isFalse);
    // The temporary skip is gone: playing again does not jump over [10, 12].
    await p().togglePlay();
    engine.position = 11;
    p().tick();
    expect(engine.seeks.last, 12);
    expect(engine.seeks, hasLength(2));
  });

  test('view follows the playhead', () async {
    c.read(editorProvider.notifier).setView(const ViewWindow(0, 5));
    await p().togglePlay();
    engine.position = 6;
    p().tick();
    expect(c.read(editorProvider).view.start, closeTo(5.5, 1e-9));
  });

  test('opening a file pauses and loads it once', () async {
    await p().togglePlay();
    await p().openFile('/x/a.mp3');
    await p().openFile('/x/a.mp3');
    expect(engine.playing, isFalse);
    expect(engine.opened, '/x/a.mp3');
  });
}
