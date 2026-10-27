import 'dart:math';
import 'dart:typed_data';

import 'crc16.dart';
import 'mp3_layout.dart';

int _u32be(Uint8List b, int i) => (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];

void _w32be(Uint8List b, int i, int v) {
  b[i] = (v >> 24) & 255;
  b[i + 1] = (v >> 16) & 255;
  b[i + 2] = (v >> 8) & 255;
  b[i + 3] = v & 255;
}

void _w16be(Uint8List b, int i, int v) {
  b[i] = (v >> 8) & 255;
  b[i + 1] = v & 255;
}

final _lameEncoder = RegExp(r'^[A-Za-z]{4}$');

/// Builds one MP3 file from the frames of [src] marked 1 in [keep], with [head] and
/// [tail] as its tags. The Xing/Info + LAME header is rewritten to describe the result;
/// a VBRI header is dropped.
Uint8List buildOutput(
  Uint8List src,
  Mp3Layout p,
  Uint8List keep, {
  required Uint8List head,
  required Uint8List? tail,
  required bool keepEncoderDelay,
  required bool keepEndPadding,
}) {
  final n = p.frameCount;
  final runs = <(int, int)>[];
  var audioBytes = 0, kept = 0;
  for (var k = 0; k < n; k++) {
    if (keep[k] == 0) continue;
    kept++;
    final s = p.offsets[k], e = s + p.lengths[k];
    audioBytes += p.lengths[k];
    if (runs.isNotEmpty && runs.last.$2 == s) {
      runs.last = (runs.last.$1, e);
    } else {
      runs.add((s, e));
    }
  }

  final out = BytesBuilder(copy: false)..add(head);
  final info = p.info;
  if (info != null && info.kind == InfoKind.xing) {
    final f = src.sublist(info.offset, info.offset + info.length);
    final frameLength = f.length, total = frameLength + audioBytes;
    var q = info.xingOffset;
    final flags = _u32be(f, q + 4);
    q += 8;
    if (flags & 1 != 0) {
      _w32be(f, q, kept);
      q += 4;
    }
    if (flags & 2 != 0) {
      _w32be(f, q, total);
      q += 4;
    }
    if (flags & 4 != 0) {
      final cum = Float64List(kept + 1);
      var c = 0.0;
      var j = 0;
      for (var k = 0; k < n; k++) {
        if (keep[k] == 1) {
          cum[j++] = c;
          c += p.lengths[k];
        }
      }
      cum[kept] = c;
      for (var t = 0; t < 100; t++) {
        final fi = min(kept, (t / 100 * kept).floor());
        f[q + t] = min(255, ((frameLength + cum[fi]) / total * 256).floor());
      }
      q += 100;
    }
    if (flags & 8 != 0) q += 4;
    if (q + 36 <= frameLength && _lameEncoder.hasMatch(String.fromCharCodes(f.sublist(q, q + 4)))) {
      if (!keepEndPadding) {
        f[q + 22] &= 0xF0;
        f[q + 23] = 0;
      }
      if (!keepEncoderDelay) {
        f[q + 21] = 0;
        f[q + 22] &= 0x0F;
      }
      _w32be(f, q + 28, total);
      var crc = 0;
      for (final (s, e) in runs) {
        crc = crc16(crc, src, s, e);
      }
      _w16be(f, q + 32, crc);
      _w16be(f, q + 34, crc16(0, f, 0, q + 34));
    }
    out.add(f);
  }
  for (final (s, e) in runs) {
    out.add(Uint8List.sublistView(src, s, e));
  }
  if (tail != null) out.add(tail);
  return out.takeBytes();
}
