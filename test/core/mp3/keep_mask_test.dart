import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/core/frame_range.dart';
import 'package:mp3_direct_cut/core/mp3/keep_mask.dart';

import '../../support/fixtures.dart';

void main() {
  late Uint16List mdb;
  setUp(() => mdb = Uint16List(100));

  test('deleted range', () {
    final k = keepMask(syntheticLayout(100, mainDataBegin: mdb), [const FrameRange(10, 20)]);
    expect(k[9], 1);
    expect(k.sublist(10, 20), everyElement(0));
    expect(k[20], 1);
  });

  test('reservoir: drops until a self-contained frame within 3', () {
    mdb[20] = 5;
    mdb[21] = 3;
    final k = keepMask(syntheticLayout(100, mainDataBegin: mdb), [const FrameRange(10, 20)]);
    expect([k[20], k[21], k[22]], [0, 0, 1]);
  });

  test('reservoir: gives up after 3 frames', () {
    for (var i = 20; i <= 23; i++) {
      mdb[i] = 1;
    }
    expect(keepMask(syntheticLayout(100, mainDataBegin: mdb), [const FrameRange(10, 20)])[20], 1);
  });

  test('normalizeRanges merges overlapping and touching, drops empty', () {
    expect(
      normalizeRanges(const [
        FrameRange(30, 40),
        FrameRange(5, 10),
        FrameRange(10, 12),
        FrameRange(35, 50),
        FrameRange(60, 60),
      ]),
      const [FrameRange(5, 12), FrameRange(30, 50)],
    );
  });
}
