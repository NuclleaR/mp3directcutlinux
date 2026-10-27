import 'dart:convert';
import 'dart:typed_data';

class TitledBytes {
  const TitledBytes(this.bytes, {required this.updated});

  final Uint8List bytes;
  final bool updated;
}

int _syncsafe(Uint8List b, int i) => ((b[i] & 127) << 21) | ((b[i + 1] & 127) << 14) | ((b[i + 2] & 127) << 7) | (b[i + 3] & 127);
int _u32(Uint8List b, int i) => (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
List<int> _syncsafeBytes(int v) => [(v >> 21) & 127, (v >> 14) & 127, (v >> 7) & 127, v & 127];
List<int> _u32Bytes(int v) => [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255];

List<int> _titleFrame(int major, String title) {
  final content = major == 4
      ? [3, ...utf8.encode(title)]
      : [1, 0xFF, 0xFE, for (final u in title.codeUnits) ...[u & 255, u >> 8]];
  return [...latin1.encode('TIT2'), ...(major == 4 ? _syncsafeBytes : _u32Bytes)(content.length), 0, 0, ...content];
}

/// Sets the Title (TIT2) of the first ID3v2 tag in [head]; every other byte of the tag is
/// kept. With no tag at all a minimal v2.3 tag is created. Tags this cannot rewrite safely
/// (v2.2, tag-level unsynchronisation, malformed) come back unchanged with `updated: false`.
TitledBytes id3v2WithTitle(Uint8List head, String title) {
  if (head.isEmpty) {
    final frame = _titleFrame(3, title);
    return TitledBytes(
      Uint8List.fromList([...latin1.encode('ID3'), 3, 0, 0, ..._syncsafeBytes(frame.length), ...frame]),
      updated: true,
    );
  }
  final unchanged = TitledBytes(head, updated: false);
  if (head.length < 10 || head[0] != 0x49 || head[1] != 0x44 || head[2] != 0x33) return unchanged;
  final major = head[3], flags = head[5];
  if ((major != 3 && major != 4) || flags & 0x80 != 0) return unchanged;
  final tagEnd = 10 + _syncsafe(head, 6);
  final footer = major == 4 && flags & 0x10 != 0 ? 10 : 0;
  if (tagEnd + footer > head.length) return unchanged;

  var p = 10;
  if (flags & 0x40 != 0) {
    if (p + 4 > tagEnd) return unchanged;
    p += major == 3 ? 4 + _u32(head, 10) : _syncsafe(head, 10);
  }
  final framesStart = p;
  final frames = <List<int>>[];
  var replaced = false;
  while (p + 10 <= tagEnd && head[p] != 0) {
    final size = major == 4 ? _syncsafe(head, p + 4) : _u32(head, p + 4);
    final frameEnd = p + 10 + size;
    if (frameEnd > tagEnd) return unchanged;
    final isTitle = head[p] == 0x54 && head[p + 1] == 0x49 && head[p + 2] == 0x54 && head[p + 3] == 0x32;
    if (isTitle && !replaced) {
      frames.add(_titleFrame(major, title));
      replaced = true;
    } else {
      frames.add(head.sublist(p, frameEnd));
    }
    p = frameEnd;
  }
  if (!replaced) frames.insert(0, _titleFrame(major, title));
  final padding = tagEnd - p;

  final body = [...head.sublist(10, framesStart), for (final f in frames) ...f, ...Uint8List(padding)];
  final out = BytesBuilder(copy: false)
    ..add([...head.sublist(0, 6), ..._syncsafeBytes(body.length)])
    ..add(body);
  if (footer > 0) out.add([...latin1.encode('3DI'), ...head.sublist(tagEnd + 3, tagEnd + 6), ..._syncsafeBytes(body.length)]);
  out.add(head.sublist(tagEnd + footer));
  return TitledBytes(out.takeBytes(), updated: true);
}

/// Sets the ID3v1 title when [title] fits Latin-1; otherwise returns [tail] unchanged.
Uint8List? id3v1WithTitle(Uint8List? tail, String title) {
  if (tail == null || title.codeUnits.any((u) => u > 0xFF)) return tail;
  final out = Uint8List.fromList(tail)..fillRange(3, 33, 0);
  final units = title.codeUnits;
  for (var i = 0; i < units.length && i < 30; i++) {
    out[3 + i] = units[i];
  }
  return out;
}
