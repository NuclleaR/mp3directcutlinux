import 'dart:math';

import 'package:flutter/foundation.dart';

/// The visible part of the file: [span] seconds starting at [start].
@immutable
class ViewWindow {
  const ViewWindow(this.start, this.span);

  final double start;
  final double span;

  ViewWindow clamp(double duration) {
    if (duration <= 0) return const ViewWindow(0, 1);
    final s = min(duration, max(0.05, span));
    return ViewWindow(min(max(0, start), max(0, duration - s)), s);
  }

  ViewWindow zoomAt(double t, double factor, double duration) {
    final rel = (t - start) / span;
    final s = span * factor;
    return ViewWindow(t - rel * s, s).clamp(duration);
  }

  ViewWindow pan(double deltaSeconds, double duration) => ViewWindow(start + deltaSeconds, span).clamp(duration);

  double xToT(double x, double width) => start + x / width * span;

  double tToX(double t, double width) => (t - start) / span * width;

  @override
  bool operator ==(Object other) => other is ViewWindow && other.start == start && other.span == span;

  @override
  int get hashCode => Object.hash(start, span);
}
