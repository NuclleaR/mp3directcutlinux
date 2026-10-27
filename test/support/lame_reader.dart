import 'dart:typed_data';

import 'package:mp3_direct_cut/core/mp3/crc16.dart';
import 'package:mp3_direct_cut/core/mp3/mp3_parser.dart';

class LameFields {
  LameFields({
    required this.frames,
    required this.bytes,
    required this.delay,
    required this.padding,
    required this.musicLength,
    required this.musicCrc,
    required this.tagCrc,
    required this.tagCrcComputed,
  });

  final int frames, bytes, delay, padding, musicLength, musicCrc, tagCrc, tagCrcComputed;
}

int _u32(Uint8List b, int i) => (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
int _u16(Uint8List b, int i) => (b[i] << 8) | b[i + 1];

/// Reads the Xing/Info header and the LAME tag of [file]'s Info frame.
LameFields readLame(Uint8List file) {
  final info = parseMp3(file).info!;
  final f = Uint8List.sublistView(file, info.offset, info.offset + info.length);
  var q = info.xingOffset;
  final flags = _u32(f, q + 4);
  q += 8;
  var frames = -1, bytes = -1;
  if (flags & 1 != 0) {
    frames = _u32(f, q);
    q += 4;
  }
  if (flags & 2 != 0) {
    bytes = _u32(f, q);
    q += 4;
  }
  if (flags & 4 != 0) q += 100;
  if (flags & 8 != 0) q += 4;
  return LameFields(
    frames: frames,
    bytes: bytes,
    delay: (f[q + 21] << 4) | (f[q + 22] >> 4),
    padding: ((f[q + 22] & 0x0F) << 8) | f[q + 23],
    musicLength: _u32(f, q + 28),
    musicCrc: _u16(f, q + 32),
    tagCrc: _u16(f, q + 34),
    tagCrcComputed: crc16(0, f, 0, q + 34),
  );
}
