import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/audio/native_audio_engine.dart';

import '../support/native_lib.dart';

void main() {
  late String lib;
  late NativeAudioEngine engine;
  const fixture = 'test/fixtures/cbr_stereo_44k.mp3';

  setUpAll(() => lib = buildPlayerLib());
  // The null backend plays in real time without a sound card.
  setUp(() => engine = NativeAudioEngine(libraryPath: lib, silent: true));
  tearDown(() => engine.dispose());

  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  test('opens a file paused at the start', () async {
    await engine.open(fixture);
    expect(engine.playing, isFalse);
    expect(engine.position, 0);
  });

  test('play advances the position, pause holds it', () async {
    await engine.open(fixture);
    await engine.play();
    expect(engine.playing, isTrue);
    await wait(400);
    expect(engine.position, greaterThan(0.2));
    await engine.pause();
    final held = engine.position;
    await wait(150);
    expect(engine.playing, isFalse);
    expect(engine.position, held);
  });

  test('seek lands on the exact time, playing or not', () async {
    await engine.open(fixture);
    await engine.seek(4.5);
    expect(engine.position, closeTo(4.5, 1e-4));
    await engine.play();
    await engine.seek(7.25);
    expect(engine.position, closeTo(7.25, 0.05));
  });

  test('playing to the end stops and reports it', () async {
    await engine.open(fixture);
    final stopped = engine.playingStream.firstWhere((p) => !p);
    await engine.seek(9.8);
    await engine.play();
    await stopped.timeout(const Duration(seconds: 3));
    expect(engine.playing, isFalse);
  });

  test('a file that is not MP3 cannot be opened', () async {
    final dir = Directory.systemTemp.createTempSync('player');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bad = File('${dir.path}/bad.mp3')..writeAsStringSync('0123456789');
    await expectLater(engine.open(bad.path), throwsA(isA<FileSystemException>()));
  });
}
