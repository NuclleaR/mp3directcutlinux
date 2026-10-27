import 'dart:typed_data';

import 'package:mp3_direct_cut/core/analysis/file_analysis.dart';
import 'package:mp3_direct_cut/core/analysis/native_analyzer.dart';

import 'fixtures.dart';

/// 1000 frames of 1152 samples at 44.1 kHz (~26.1 s); loud everywhere except frames 400–410.
FileAnalysis fakeAnalysis({String path = '/tmp/a.mp3', bool withWave = true}) {
  final rms = Float32List(1000)..fillRange(0, 1000, 0.5);
  rms.fillRange(400, 411, 0);
  final peaks = Float32List(5225)..fillRange(0, 5225, 0.5);
  return FileAnalysis(
    path: path,
    size: 1,
    mtimeMs: 1,
    layout: syntheticLayout(1000),
    wave: withWave ? WaveAnalysis(peaks: peaks, rms: rms, peaksPerSecond: 200, peakScale: 1.84) : null,
    waveError: withWave ? null : 'no decoder',
  );
}
