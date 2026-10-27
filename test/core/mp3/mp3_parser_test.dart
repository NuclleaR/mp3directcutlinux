import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/core/mp3/mp3_layout.dart';
import 'package:mp3_direct_cut/core/mp3/mp3_parser.dart';

import '../../support/fixtures.dart';

void main() {
  test('CBR stereo fixture', () {
    final p = parseMp3(fixture('cbr_stereo_44k.mp3'));
    expect(p.sampleRate, 44100);
    expect(p.samplesPerFrame, 1152);
    expect(p.info?.kind, InfoKind.xing);
    expect(p.frameCount, inInclusiveRange(380, 392));
    expect(ascii(p.head, 0, 3), 'ID3');
    expect(ascii(p.tail!, 0, 3), 'TAG');
  });

  test('MPEG-2 mono VBR fixture', () {
    final p = parseMp3(fixture('vbr_mono_22k.mp3'));
    expect(p.sampleRate, 22050);
    expect(p.samplesPerFrame, 576);
    expect(p.info?.kind, InfoKind.xing);
  });

  test('no tags, no info frame', () {
    final p = parseMp3(fixture('plain_cbr.mp3'));
    expect(p.head, isEmpty);
    expect(p.tail, isNull);
    expect(p.info, isNull);
    expect(p.frameCount, greaterThan(380));
  });

  test('not an MP3', () {
    expect(parseMp3(Uint8List(0)).frameCount, 0);
    expect(parseMp3(Uint8List.fromList(utf8.encode('hello ' * 2000))).frameCount, 0);
    final src = fixture('plain_cbr.mp3');
    expect(parseMp3(Uint8List.sublistView(src, 0, 300)).frameCount, lessThan(2));
  });

  test('junk between frames is skipped', () {
    final src = fixture('plain_cbr.mp3');
    final p = parseMp3(src);
    final cut = p.offsets[10] + p.lengths[10];
    final withJunk = Uint8List.fromList([...src.sublist(0, cut), ...Uint8List(100), ...src.sublist(cut)]);
    expect(parseMp3(withJunk).frameCount, p.frameCount);
  });

  test('synthetic 1-hour file parses in under 2 s', () {
    final src = fixture('plain_cbr.mp3');
    final p = parseMp3(src);
    final audio = audioBytes(src, p);
    final big = BytesBuilder(copy: false);
    for (var i = 0; i < 360; i++) {
      big.add(audio);
    }
    final bytes = big.takeBytes();
    final sw = Stopwatch()..start();
    final q = parseMp3(bytes);
    sw.stop();
    expect(q.frameCount, p.frameCount * 360);
    expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
  });
}
