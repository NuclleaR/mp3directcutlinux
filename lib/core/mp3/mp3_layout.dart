import 'dart:typed_data';

enum InfoKind { xing, vbri }

/// The VBR header frame (Xing/Info or VBRI) that precedes the audio frames.
class InfoFrame {
  const InfoFrame({required this.kind, required this.offset, required this.length, required this.xingOffset});

  final InfoKind kind;
  final int offset;
  final int length;

  /// Offset of the `Xing`/`Info` tag inside the frame (0 for VBRI).
  final int xingOffset;
}

/// Where everything is in an MP3 file: tags, the VBR header and every audio frame.
class Mp3Layout {
  const Mp3Layout({
    required this.head,
    required this.tail,
    required this.sampleRate,
    required this.samplesPerFrame,
    required this.info,
    required this.offsets,
    required this.lengths,
    required this.mainDataBegin,
  });

  /// ID3v2 tag(s) before the first frame.
  final Uint8List head;

  /// ID3v1 tag (128 bytes) at the end, if any.
  final Uint8List? tail;
  final int sampleRate;
  final int samplesPerFrame;
  final InfoFrame? info;
  final Uint32List offsets;
  final Uint32List lengths;

  /// `main_data_begin` of every frame: how many bytes it borrows from earlier frames.
  final Uint16List mainDataBegin;

  int get frameCount => offsets.length;

  double get frameDuration => sampleRate == 0 ? 0 : samplesPerFrame / sampleRate;
}
