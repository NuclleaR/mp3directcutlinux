import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/core/frame_range.dart';
import 'package:mp3_direct_cut/core/mp3/mp3_parser.dart';
import 'package:mp3_direct_cut/core/mp3/mp3_writer.dart';
import 'package:mp3_direct_cut/core/mp3/parts.dart';

import '../../support/fixtures.dart';
import '../../support/lame_reader.dart';

void main() {
  late Uint16List mdb;
  setUp(() => mdb = Uint16List(100));

  test('two splits make three parts', () {
    final ps = planParts(syntheticLayout(100, mainDataBegin: mdb), const [], const [30, 60]);
    expect(ps.map((x) => x.keptCount), [30, 30, 40]);
    expect(ps.map((x) => x.anchorFrame), [0, 30, 60]);
    expect([ps.first.startsAtSourceStart, ps.first.endsAtSourceEnd, ps.last.endsAtSourceEnd], [true, false, true]);
    expect(keptFrameTotal(ps), 100);
  });

  test('split inside a delete range', () {
    final ps = planParts(syntheticLayout(100, mainDataBegin: mdb), const [FrameRange(25, 35)], const [30]);
    expect(ps.map((x) => x.keptCount), [25, 65]);
  });

  test('empty part keeps its number', () {
    final ps = planParts(syntheticLayout(100, mainDataBegin: mdb), const [FrameRange(30, 60)], const [30, 60]);
    expect(ps[1].isEmpty, isTrue);
    expect(ps[2].index, 2);
  });

  test('reservoir rule at a part start', () {
    mdb[30] = 4;
    final ps = planParts(syntheticLayout(100, mainDataBegin: mdb), const [], const [30]);
    expect([ps[1].keep[30], ps[1].keep[31]], [0, 1]);
  });

  test('no splits: one part covering the file', () {
    final ps = planParts(syntheticLayout(100, mainDataBegin: mdb), const [FrameRange(0, 10)], const []);
    expect(ps, hasLength(1));
    expect(ps.single.startsAtSourceStart, isFalse);
    expect(ps.single.endsAtSourceEnd, isTrue);
  });

  test('writing two parts of a real file', () {
    final src = fixture('cbr_stereo_44k.mp3');
    final p = parseMp3(src);
    final ps = planParts(p, const [], const [150]);
    final outs = [
      for (final part in ps)
        buildOutput(src, p, part.keep,
            head: p.head,
            tail: p.tail,
            keepEncoderDelay: part.startsAtSourceStart,
            keepEndPadding: part.endsAtSourceEnd),
    ];
    expect(outs.map((o) => parseMp3(o).frameCount), ps.map((x) => x.keptCount));
    expect(readLame(outs[0]).padding, 0);
    expect(readLame(outs[0]).delay, greaterThan(0));
    expect(readLame(outs[1]).delay, 0);
    expect(readLame(outs[1]).padding, greaterThan(0));
  });
}
