import 'dart:math';
import 'dart:typed_data';

import 'frame_header.dart';
import 'mp3_layout.dart';

String _ascii(Uint8List b, int i, int n) {
  final codes = <int>[];
  for (var k = 0; k < n && i + k < b.length; k++) {
    codes.add(b[i + k]);
  }
  return String.fromCharCodes(codes);
}

int _u32le(Uint8List b, int i) => b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24);

Mp3Layout parseMp3(Uint8List b) {
  var pos = 0;
  while (pos + 10 <= b.length && b[pos] == 0x49 && b[pos + 1] == 0x44 && b[pos + 2] == 0x33) {
    final size = ((b[pos + 6] & 127) << 21) | ((b[pos + 7] & 127) << 14) | ((b[pos + 8] & 127) << 7) | (b[pos + 9] & 127);
    pos += 10 + size + ((b[pos + 5] & 0x10) != 0 ? 10 : 0);
  }
  pos = min(pos, b.length);
  final head = b.sublist(0, pos);

  var end = b.length;
  Uint8List? tail;
  if (end - pos >= 128 && _ascii(b, end - 128, 3) == 'TAG') {
    tail = b.sublist(end - 128, end);
    end -= 128;
  }
  if (end - pos >= 32 && _ascii(b, end - 32, 8) == 'APETAGEX') {
    final size = _u32le(b, end - 20), flags = _u32le(b, end - 12);
    end = max(pos, end - size - ((flags & 0x80000000) != 0 ? 32 : 0));
  }

  var sampleRate = 0;
  // A frame only counts if the next one (or the end of the audio) follows right after it.
  int find(int from) {
    for (var i = from; i + 4 <= end; i++) {
      final h = readFrameHeader(b, i, end);
      if (h == null || (sampleRate != 0 && h.sampleRate != sampleRate)) continue;
      final j = i + h.length;
      if (j == end) return i;
      final h2 = readFrameHeader(b, j, end);
      if (h2 != null && h2.sampleRate == h.sampleRate) return i;
    }
    return -1;
  }

  final offsets = <int>[], lengths = <int>[], mainDataBegin = <int>[];
  var samplesPerFrame = 0;
  FrameHeader? first;
  var i = find(pos);
  while (i >= 0 && i < end) {
    final h = readFrameHeader(b, i, end);
    if (h == null || i + h.length > end || (sampleRate != 0 && h.sampleRate != sampleRate)) {
      i = find(i + 1);
      continue;
    }
    if (sampleRate == 0) {
      sampleRate = h.sampleRate;
      samplesPerFrame = h.samplesPerFrame;
      first = h;
    }
    offsets.add(i);
    lengths.add(h.length);
    final s = i + 4 + (h.protection == 0 ? 2 : 0);
    mainDataBegin.add(h.version == 3 ? (b[s] << 1) | (b[s + 1] >> 7) : b[s]);
    i += h.length;
  }

  InfoFrame? info;
  if (offsets.isNotEmpty) {
    final o = offsets.first;
    final side = first!.version == 3 ? (first.mono ? 17 : 32) : (first.mono ? 9 : 17);
    final tag = _ascii(b, o + 4 + side, 4);
    if (tag == 'Xing' || tag == 'Info') {
      info = InfoFrame(kind: InfoKind.xing, offset: o, length: lengths.first, xingOffset: 4 + side);
    } else if (_ascii(b, o + 36, 4) == 'VBRI') {
      info = InfoFrame(kind: InfoKind.vbri, offset: o, length: lengths.first, xingOffset: 0);
    }
    if (info != null) {
      offsets.removeAt(0);
      lengths.removeAt(0);
      mainDataBegin.removeAt(0);
    }
  }

  return Mp3Layout(
    head: head,
    tail: tail,
    sampleRate: sampleRate,
    samplesPerFrame: samplesPerFrame,
    info: info,
    offsets: Uint32List.fromList(offsets),
    lengths: Uint32List.fromList(lengths),
    mainDataBegin: Uint16List.fromList(mainDataBegin),
  );
}
