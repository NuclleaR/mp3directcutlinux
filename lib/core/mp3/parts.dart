import 'dart:typed_data';

import '../frame_range.dart';
import 'keep_mask.dart';
import 'mp3_layout.dart';

/// One output file: the frames of `[startFrame, endFrame)` that survive the deletes.
class PartPlan {
  const PartPlan({
    required this.index,
    required this.anchorFrame,
    required this.startFrame,
    required this.endFrame,
    required this.keep,
    required this.keptCount,
    required this.startsAtSourceStart,
    required this.endsAtSourceEnd,
  });

  final int index;

  /// 0 for the first part, otherwise the split point that starts it; part names hang off it.
  final int anchorFrame;
  final int startFrame;
  final int endFrame;

  /// Keep mask over the whole source; 0 everywhere outside this part.
  final Uint8List keep;
  final int keptCount;

  /// The first kept frame is the source's first audio frame.
  final bool startsAtSourceStart;

  /// The last kept frame is the source's last audio frame.
  final bool endsAtSourceEnd;

  bool get isEmpty => keptCount == 0;
}

List<PartPlan> planParts(Mp3Layout p, List<FrameRange> deletes, List<int> splits) {
  final n = p.frameCount;
  final deleted = deletionMask(n, deletes);
  final bounds = [0, ...({...splits.where((s) => s > 0 && s < n)}.toList()..sort()), n];
  final parts = <PartPlan>[];
  for (var i = 0; i + 1 < bounds.length; i++) {
    final start = bounds[i], end = bounds[i + 1];
    final keep = Uint8List(n)..setRange(start, end, deleted, start);
    // Frames before the part are not in this file, so the reservoir rule applies at its start too.
    applyReservoirRule(keep, p.mainDataBegin);
    var kept = 0, first = -1, last = -1;
    for (var k = start; k < end; k++) {
      if (keep[k] == 0) continue;
      kept++;
      if (first < 0) first = k;
      last = k;
    }
    parts.add(PartPlan(
      index: i,
      anchorFrame: start,
      startFrame: start,
      endFrame: end,
      keep: keep,
      keptCount: kept,
      startsAtSourceStart: first == 0,
      endsAtSourceEnd: kept > 0 && last == n - 1,
    ));
  }
  return parts;
}

int keptFrameTotal(List<PartPlan> parts) => parts.fold(0, (sum, p) => sum + p.keptCount);
