import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../mp3/mp3_layout.dart';

/// Loudness data for drawing the waveform and snapping to silence.
class WaveAnalysis {
  const WaveAnalysis({required this.peaks, required this.rms, required this.peaksPerSecond, required this.peakScale});

  /// Max |sample| per 1/[peaksPerSecond] s.
  final Float32List peaks;

  /// RMS of every audio frame, aligned with [Mp3Layout.offsets].
  final Float32List rms;
  final int peaksPerSecond;

  /// Multiplier that makes the loudest peak 92% of the half-height.
  final double peakScale;
}

typedef _AnalyzeNative = Int32 Function(
    Pointer<Uint8>, Int64, Pointer<Uint32>, Int32, Int32, Int32, Int32, Pointer<Float>, Pointer<Float>, Int32);
typedef _AnalyzeDart = int Function(
    Pointer<Uint8>, int, Pointer<Uint32>, int, int, int, int, Pointer<Float>, Pointer<Float>, int);

/// Where the Linux build installs the library: `lib/` next to the executable.
String defaultAnalyzerLibraryPath() => '${File(Platform.resolvedExecutable).parent.path}/lib/libmp3_analyze.so';

WaveAnalysis analyzeFrames(Uint8List bytes, Mp3Layout layout, {int peaksPerSecond = 200, String? libraryPath}) {
  final analyze = DynamicLibrary.open(libraryPath ?? defaultAnalyzerLibraryPath())
      .lookupFunction<_AnalyzeNative, _AnalyzeDart>('mp3_analyze');
  final n = layout.frameCount;
  final cap = (n * layout.samplesPerFrame * peaksPerSecond / max(1, layout.sampleRate)).ceil() + 2;
  final data = malloc<Uint8>(max(1, bytes.length));
  final offsets = malloc<Uint32>(max(1, n));
  final rms = malloc<Float>(max(1, n));
  final peaks = malloc<Float>(cap);
  try {
    data.asTypedList(bytes.length).setAll(0, bytes);
    offsets.asTypedList(n).setAll(0, layout.offsets);
    final count = analyze(data, bytes.length, offsets, n, layout.sampleRate, layout.samplesPerFrame, peaksPerSecond,
        rms, peaks, cap);
    if (count < 0) throw StateError('mp3_analyze rejected its arguments');
    final peakList = Float32List.fromList(peaks.asTypedList(count));
    var loudest = 1e-6;
    for (final v in peakList) {
      if (v > loudest) loudest = v;
    }
    return WaveAnalysis(
      peaks: peakList,
      rms: Float32List.fromList(rms.asTypedList(n)),
      peaksPerSecond: peaksPerSecond,
      peakScale: 0.92 / loudest,
    );
  } finally {
    malloc
      ..free(data)
      ..free(offsets)
      ..free(rms)
      ..free(peaks);
  }
}
