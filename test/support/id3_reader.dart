import 'dart:convert';
import 'dart:typed_data';

int _syncsafe(Uint8List b, int i) => (b[i] << 21) | (b[i + 1] << 14) | (b[i + 2] << 7) | b[i + 3];
int _u32(Uint8List b, int i) => (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];

/// Raw content of the first [frameId] frame in the leading ID3v2 tag of [file].
Uint8List? readId3v2Frame(Uint8List file, String frameId) {
  if (file.length < 10 || String.fromCharCodes(file.sublist(0, 3)) != 'ID3') return null;
  final major = file[3];
  final end = 10 + _syncsafe(file, 6);
  var p = 10;
  if (file[5] & 0x40 != 0) p += major == 3 ? 4 + _u32(file, 10) : _syncsafe(file, 10);
  while (p + 10 <= end && file[p] != 0) {
    final id = String.fromCharCodes(file.sublist(p, p + 4));
    final size = major == 4 ? _syncsafe(file, p + 4) : _u32(file, p + 4);
    if (id == frameId) return file.sublist(p + 10, p + 10 + size);
    p += 10 + size;
  }
  return null;
}

String _decodeText(Uint8List c) {
  final body = c.sublist(1);
  switch (c[0]) {
    case 0:
      return latin1.decode(body).replaceAll('\u0000', '');
    case 1:
    case 2:
      final le = c[0] == 1 && body.length >= 2 && body[0] == 0xFF && body[1] == 0xFE;
      final be = c[0] == 2 || (body.length >= 2 && body[0] == 0xFE && body[1] == 0xFF);
      final start = c[0] == 1 ? 2 : 0;
      final units = <int>[];
      for (var i = start; i + 1 < body.length; i += 2) {
        units.add(le || !be ? body[i] | (body[i + 1] << 8) : (body[i] << 8) | body[i + 1]);
      }
      return String.fromCharCodes(units).replaceAll('\u0000', '');
    default:
      return utf8.decode(body).replaceAll('\u0000', '');
  }
}

String? readId3v2Text(Uint8List file, String frameId) {
  final c = readId3v2Frame(file, frameId);
  return c == null ? null : _decodeText(c);
}

String? readId3v2Title(Uint8List file) => readId3v2Text(file, 'TIT2');

String readId3v1Title(Uint8List file) {
  final t = file.sublist(file.length - 128 + 3, file.length - 128 + 33);
  return latin1.decode(t).replaceAll('\u0000', '').trimRight();
}
