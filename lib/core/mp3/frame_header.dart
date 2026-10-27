import 'dart:typed_data';

const _bitratesV1 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320];
const _bitratesV2 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160];
const _sampleRates = {
  3: [44100, 48000, 32000],
  2: [22050, 24000, 16000],
  0: [11025, 12000, 8000],
};

/// An MPEG audio Layer III frame header. [version] uses the raw header bits:
/// 3 = MPEG-1, 2 = MPEG-2, 0 = MPEG-2.5.
class FrameHeader {
  const FrameHeader({
    required this.length,
    required this.sampleRate,
    required this.version,
    required this.protection,
    required this.samplesPerFrame,
    required this.mono,
  });

  final int length, sampleRate, version, protection, samplesPerFrame;
  final bool mono;
}

FrameHeader? readFrameHeader(Uint8List b, int i, int end) {
  if (i + 4 > end || b[i] != 0xFF || (b[i + 1] & 0xE0) != 0xE0) return null;
  final version = (b[i + 1] >> 3) & 3, layer = (b[i + 1] >> 1) & 3, protection = b[i + 1] & 1;
  if (version == 1 || layer != 1) return null;
  final bitrateIndex = b[i + 2] >> 4, rateIndex = (b[i + 2] >> 2) & 3, padding = (b[i + 2] >> 1) & 1;
  if (bitrateIndex == 0 || bitrateIndex == 15 || rateIndex == 3) return null;
  final bitrate = (version == 3 ? _bitratesV1 : _bitratesV2)[bitrateIndex] * 1000;
  final sampleRate = _sampleRates[version]![rateIndex];
  return FrameHeader(
    length: (version == 3 ? 144 : 72) * bitrate ~/ sampleRate + padding,
    sampleRate: sampleRate,
    version: version,
    protection: protection,
    samplesPerFrame: version == 3 ? 1152 : 576,
    mono: ((b[i + 3] >> 6) & 3) == 3,
  );
}
