import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../mp3/frame_header.dart';
import '../mp3/mp3_layout.dart';
import '../mp3/mp3_parser.dart';
import 'native_analyzer.dart';

class FileAnalysis {
  const FileAnalysis({
    required this.path,
    required this.size,
    required this.mtimeMs,
    required this.layout,
    required this.wave,
    required this.waveError,
  });

  final String path;
  final int size;
  final int mtimeMs;

  /// `layout.frameCount == 0` means the file is not an MP3.
  final Mp3Layout layout;

  /// Null when decoding failed ([waveError] says why); cutting still works without it.
  final WaveAnalysis? wave;
  final String? waveError;
}

/// Reads, parses and decodes [path] in a background isolate.
Future<FileAnalysis> analyzeFile(String path, {String? libraryPath}) {
  final lib = libraryPath ?? defaultAnalyzerLibraryPath();
  return Isolate.run(() {
    final file = File(path);
    final stat = file.statSync();
    final bytes = file.readAsBytesSync();
    final layout = parseMp3(bytes);
    WaveAnalysis? wave;
    String? error;
    if (layout.frameCount > 0) {
      try {
        wave = analyzeFrames(bytes, layout, libraryPath: lib);
      } catch (e) {
        error = e.toString();
      }
    }
    return FileAnalysis(
      path: path,
      size: stat.size,
      mtimeMs: stat.modified.millisecondsSinceEpoch,
      layout: layout,
      wave: wave,
      waveError: error,
    );
  });
}

/// Cheap check for the file list: skips the ID3v2 tag and looks for two consecutive
/// valid frame headers in the next 64 KB.
Future<bool> probeMp3(String path) async {
  final raf = await File(path).open();
  try {
    var pos = 0;
    final id3 = await raf.read(10);
    if (id3.length == 10 && id3[0] == 0x49 && id3[1] == 0x44 && id3[2] == 0x33) {
      pos = 10 + (((id3[6] & 127) << 21) | ((id3[7] & 127) << 14) | ((id3[8] & 127) << 7) | (id3[9] & 127));
      if (id3[5] & 0x10 != 0) pos += 10;
    }
    await raf.setPosition(pos);
    final b = Uint8List.fromList(await raf.read(64 * 1024));
    for (var i = 0; i + 4 <= b.length; i++) {
      final h = readFrameHeader(b, i, b.length);
      if (h == null) continue;
      final next = readFrameHeader(b, i + h.length, b.length);
      if (next != null && next.sampleRate == h.sampleRate) return true;
    }
    return false;
  } finally {
    await raf.close();
  }
}
