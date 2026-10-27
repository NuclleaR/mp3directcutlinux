import 'dart:math';
import 'dart:typed_data';

/// The frame boundary nearest to [t] seconds.
int snapToFrame(double t, double frameDuration, int frameCount) =>
    (t / frameDuration).round().clamp(0, frameCount);

/// The quietest frame boundary within [radiusSeconds] of [t]: the one whose two
/// neighbouring frames have the lowest RMS; ties go to the nearest boundary.
int snapToQuiet(double t, Float32List rms, double frameDuration, int frameCount, {double radiusSeconds = 0.3}) {
  final n = min(frameCount, rms.length);
  final k0 = (t / frameDuration).round().clamp(0, n);
  final r = (radiusSeconds / frameDuration).round();
  var best = k0;
  var bestScore = double.infinity;
  for (var k = max(0, k0 - r); k <= min(n, k0 + r); k++) {
    final a = k > 0 ? rms[k - 1] : 0.0, b = k < n ? rms[k] : 0.0;
    final score = a + b + (k - k0).abs() * 1e-6;
    if (score < bestScore) {
      bestScore = score;
      best = k;
    }
  }
  return best;
}
