import 'package:flutter/foundation.dart';

/// Half-open range of MP3 frame indices `[start, end)`.
@immutable
class FrameRange {
  const FrameRange(this.start, this.end);

  factory FrameRange.fromJson(List<dynamic> json) => FrameRange(json[0] as int, json[1] as int);

  final int start;
  final int end;

  int get length => end - start;

  List<int> toJson() => [start, end];

  @override
  bool operator ==(Object other) => other is FrameRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '[$start, $end)';
}

/// Drops empty ranges, sorts the rest and merges the ones that overlap or touch.
List<FrameRange> normalizeRanges(Iterable<FrameRange> ranges) {
  final sorted = ranges.where((r) => r.end > r.start).toList()..sort((a, b) => a.start - b.start);
  final out = <FrameRange>[];
  for (final r in sorted) {
    if (out.isNotEmpty && r.start <= out.last.end) {
      final last = out.removeLast();
      out.add(FrameRange(last.start, r.end > last.end ? r.end : last.end));
    } else {
      out.add(r);
    }
  }
  return out;
}
