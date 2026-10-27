import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/core/frame_range.dart';
import 'package:mp3_direct_cut/core/mp3/crc16.dart';
import 'package:mp3_direct_cut/core/mp3/keep_mask.dart';
import 'package:mp3_direct_cut/core/mp3/mp3_parser.dart';
import 'package:mp3_direct_cut/core/mp3/mp3_writer.dart';

import '../../support/fixtures.dart';
import '../../support/lame_reader.dart';

void main() {
  final src = fixture('cbr_stereo_44k.mp3');
  final p = parseMp3(src);
  final keepAll = Uint8List(p.frameCount)..fillRange(0, p.frameCount, 1);

  Uint8List build(Uint8List keep, {bool delay = true, bool padding = true}) => buildOutput(
        src,
        p,
        keep,
        head: p.head,
        tail: p.tail,
        keepEncoderDelay: delay,
        keepEndPadding: padding,
      );

  test('keep everything: same audio frames, same tags', () {
    final out = build(keepAll);
    final q = parseMp3(out);
    expect(q.frameCount, p.frameCount);
    expect(audioBytes(out, q), audioBytes(src, p));
    expect(q.head, p.head);
    expect(q.tail, p.tail);
  });

  test('Xing/LAME fields describe the output', () {
    final out = build(keepMask(p, [const FrameRange(100, 200)]));
    final q = parseMp3(out);
    final l = readLame(out);
    final audio = audioBytes(out, q);
    expect(q.frameCount, lessThanOrEqualTo(p.frameCount - 100));
    expect(l.frames, q.frameCount);
    expect(l.bytes, out.length - q.head.length - q.tail!.length);
    expect(l.musicLength, l.bytes);
    expect(l.tagCrc, l.tagCrcComputed);
    expect(l.musicCrc, crc16(0, audio, 0, audio.length));
  });

  test('end padding cleared, delay kept', () {
    final source = readLame(src);
    expect(source.delay, greaterThan(0));
    expect(source.padding, greaterThan(0));
    final l = readLame(build(keepAll, padding: false));
    expect(l.padding, 0);
    expect(l.delay, source.delay);
  });

  test('delay cleared, padding kept', () {
    final source = readLame(src);
    final l = readLame(build(keepAll, delay: false));
    expect(l.delay, 0);
    expect(l.padding, source.padding);
  });
}
