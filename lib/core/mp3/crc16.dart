import 'dart:typed_data';

final _table = () {
  final t = Uint16List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = c & 1 != 0 ? (c >> 1) ^ 0xA001 : c >> 1;
    }
    t[n] = c;
  }
  return t;
}();

/// CRC-16 (poly 0xA001) as used by the LAME tag.
int crc16(int crc, Uint8List a, int start, int end) {
  for (var i = start; i < end; i++) {
    crc = (crc >> 8) ^ _table[(crc ^ a[i]) & 255];
  }
  return crc;
}
