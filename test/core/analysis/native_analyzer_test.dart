import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/core/analysis/file_analysis.dart';
import 'package:mp3_direct_cut/core/analysis/native_analyzer.dart';
import 'package:mp3_direct_cut/core/mp3/mp3_parser.dart';

import '../../support/fixtures.dart';
import '../../support/native_lib.dart';

void main() {
  late String lib;
  setUpAll(() => lib = buildNativeLib());

  final src = fixture('cbr_stereo_44k.mp3');
  final p = parseMp3(src);

  test('one RMS value per frame', () {
    expect(analyzeFrames(src, p, libraryPath: lib).rms.length, p.frameCount);
  });

  test('silence at 3–4 s is quiet, tone at 1.5 s is loud', () {
    final w = analyzeFrames(src, p, libraryPath: lib);
    expect(w.rms[(3.5 / p.frameDuration).round()], lessThan(0.01));
    expect(w.rms[(1.5 / p.frameDuration).round()], greaterThan(0.1));
  });

  test('peak count matches duration', () {
    final w = analyzeFrames(src, p, libraryPath: lib);
    expect(w.peaks.length, closeTo(p.frameCount * p.samplesPerFrame * 200 / p.sampleRate, 1));
    expect(w.peakScale, closeTo(0.92 / 0.5, 0.2));
  });

  test('MPEG-2 mono file decodes too', () {
    final vbr = fixture('vbr_mono_22k.mp3');
    final q = parseMp3(vbr);
    final w = analyzeFrames(vbr, q, libraryPath: lib);
    expect(w.rms[(1.5 / q.frameDuration).round()], greaterThan(0.1));
  });

  test('analyzeFile runs in an isolate and matches the sync result', () async {
    final a = await analyzeFile('test/fixtures/cbr_stereo_44k.mp3', libraryPath: lib);
    expect(a.layout.frameCount, p.frameCount);
    expect(a.wave!.rms, analyzeFrames(src, p, libraryPath: lib).rms);
    expect(a.size, src.length);
  });

  test('missing library → waveError set, layout still parsed', () async {
    final a = await analyzeFile('test/fixtures/cbr_stereo_44k.mp3', libraryPath: 'nope.so');
    expect(a.wave, isNull);
    expect(a.waveError, isNotNull);
    expect(a.layout.frameCount, p.frameCount);
  });

  test('probeMp3 tells MP3 files from other files', () async {
    final tmp = Directory.systemTemp.createTempSync('probe');
    addTearDown(() => tmp.deleteSync(recursive: true));
    File('${tmp.path}/text.mp3').writeAsStringSync('not really an mp3 at all');
    File('${tmp.path}/empty.mp3').writeAsBytesSync([]);
    for (final f in ['cbr_stereo_44k.mp3', 'vbr_mono_22k.mp3', 'plain_cbr.mp3']) {
      expect(await probeMp3('test/fixtures/$f'), isTrue, reason: f);
    }
    expect(await probeMp3('${tmp.path}/text.mp3'), isFalse);
    expect(await probeMp3('${tmp.path}/empty.mp3'), isFalse);
  });
}
