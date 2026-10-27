import 'dart:math';
import 'dart:typed_data';

import '../frame_range.dart';
import 'mp3_layout.dart';

/// 1 for every frame outside [deletes], 0 inside.
Uint8List deletionMask(int frameCount, List<FrameRange> deletes) {
  final keep = Uint8List(frameCount)..fillRange(0, frameCount, 1);
  for (final r in deletes) {
    keep.fillRange(max(0, min(frameCount, r.start)), max(0, min(frameCount, r.end)), 0);
  }
  return keep;
}

/// The first frame after a gap may borrow bytes from the frame before it (bit reservoir).
/// Those bytes are gone after the gap, so skip ahead up to 3 frames to one that needs
/// nothing from before; if there is none that close, keep the frame as it is.
void applyReservoirRule(Uint8List keep, Uint16List mainDataBegin) {
  final n = keep.length;
  for (var k = 1; k < n; k++) {
    if (keep[k] == 1 && keep[k - 1] == 0 && mainDataBegin[k] > 0) {
      for (var j = k + 1; j <= min(n - 1, k + 3); j++) {
        if (mainDataBegin[j] == 0) {
          keep.fillRange(k, j, 0);
          break;
        }
      }
    }
  }
}

Uint8List keepMask(Mp3Layout p, List<FrameRange> deletes) {
  final keep = deletionMask(p.frameCount, deletes);
  applyReservoirRule(keep, p.mainDataBegin);
  return keep;
}
