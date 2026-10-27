/// `m:ss.mmm`, or `h:mm:ss.mmm` from an hour on; without milliseconds `m:ss`.
String formatTime(double seconds, {bool millis = true}) {
  final t = seconds < 0 ? 0.0 : seconds;
  final h = t ~/ 3600, m = (t ~/ 60) % 60, s = t % 60;
  final ss = millis ? s.toStringAsFixed(3).padLeft(6, '0') : s.floor().toString().padLeft(2, '0');
  return '${h > 0 ? '$h:${m.toString().padLeft(2, '0')}' : '$m'}:$ss';
}

const _steps = [0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 1200, 1800, 3600];

/// Ruler step (seconds) that puts labels at least 90 px apart.
double niceStep(double spanSeconds, double widthPx) {
  for (final s in _steps) {
    if (s / spanSeconds * widthPx >= 90) return s.toDouble();
  }
  return 3600;
}
