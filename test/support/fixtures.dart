import 'dart:io';
import 'dart:typed_data';

import 'package:mp3_direct_cut/core/mp3/mp3_layout.dart';

Uint8List fixture(String name) => File('test/fixtures/$name').readAsBytesSync();

String ascii(Uint8List b, int offset, int length) =>
    String.fromCharCodes(b.sublist(offset, offset + length));

/// All audio frames of [file] (per [layout]) concatenated, without tags or the Info frame.
Uint8List audioBytes(Uint8List file, Mp3Layout layout) {
  final out = BytesBuilder(copy: false);
  for (var k = 0; k < layout.frameCount; k++) {
    out.add(Uint8List.sublistView(file, layout.offsets[k], layout.offsets[k] + layout.lengths[k]));
  }
  return out.takeBytes();
}

/// Copies [count] frames starting at [first] from [file].
Uint8List frameBytes(Uint8List file, Mp3Layout layout, int first, int count) {
  final out = BytesBuilder(copy: false);
  for (var k = first; k < first + count; k++) {
    out.add(Uint8List.sublistView(file, layout.offsets[k], layout.offsets[k] + layout.lengths[k]));
  }
  return out.takeBytes();
}

/// A layout with [n] equal frames and no real bytes behind it, for mask tests.
Mp3Layout syntheticLayout(int n, {Uint16List? mainDataBegin}) => Mp3Layout(
      head: Uint8List(0),
      tail: null,
      sampleRate: 44100,
      samplesPerFrame: 1152,
      info: null,
      offsets: Uint32List.fromList([for (var k = 0; k < n; k++) k * 418]),
      lengths: Uint32List.fromList(List.filled(n, 418)),
      mainDataBegin: mainDataBegin ?? Uint16List(n),
    );
