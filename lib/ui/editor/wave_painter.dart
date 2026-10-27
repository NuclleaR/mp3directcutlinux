import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/analysis/native_analyzer.dart';
import '../../core/time_format.dart';
import '../theme/cut_palette.dart';

/// Waveform bars for `[start, start + span]` seconds inside [area], one per pixel column.
void paintPeaks(Canvas canvas, Rect area, WaveAnalysis wave, double start, double span, Color color) {
  final mid = area.center.dy, amp = area.height / 2;
  final pr = wave.peaksPerSecond, pk = wave.peaks;
  final w = area.width.floor();
  final path = Path();
  for (var x = 0; x < w; x++) {
    final t0 = start + x / w * span, t1 = start + (x + 1) / w * span;
    final i0 = (t0 * pr).floor(), i1 = max(i0 + 1, (t1 * pr).ceil());
    var m = 0.0;
    for (var i = max(0, i0); i < i1 && i < pk.length; i++) {
      if (pk[i] > m) m = pk[i];
    }
    final h = max(0.5, m * wave.peakScale * amp);
    path.addRect(Rect.fromLTWH(area.left + x, mid - h, 1, h * 2));
  }
  canvas.drawPath(path, Paint()..color = color);
}

/// Background and bars; repaints only when the view or the size changes.
class WaveLayerPainter extends CustomPainter {
  WaveLayerPainter({required this.wave, required this.start, required this.span, required this.palette, this.top = 0, this.opacity = 1});

  final WaveAnalysis? wave;
  final double start, span, top, opacity;
  final CutPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.waveBg);
    final w = wave;
    if (w == null) return;
    paintPeaks(canvas, Rect.fromLTRB(0, top, size.width, size.height), w, start, span,
        palette.wave.withValues(alpha: opacity));
  }

  @override
  bool shouldRepaint(WaveLayerPainter old) =>
      old.wave != wave || old.start != start || old.span != span || old.palette != palette || old.top != top;
}

/// Delete ranges, selection, split points, time ruler and playhead over the main waveform.
class WaveOverlayPainter extends CustomPainter {
  WaveOverlayPainter({
    required this.start,
    required this.span,
    required this.deletes,
    required this.splits,
    required this.selection,
    required this.playhead,
    required this.palette,
    required this.ruler,
    super.repaint,
  });

  final double start, span, ruler;
  final List<(double, double)> deletes;
  final List<double> splits;
  final (double, double)? selection;
  final double Function() playhead;
  final CutPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    double x(double t) => (t - start) / span * w;
    final fill = Paint();
    final line = Paint()..strokeWidth = 1;

    for (final (a, b) in deletes) {
      final x0 = x(a), x1 = x(b);
      if (x1 < 0 || x0 > w) continue;
      canvas.drawRect(Rect.fromLTRB(x0, ruler, max(x0 + 1, x1), h), fill..color = palette.cutFill);
    }
    final sel = selection;
    if (sel != null) {
      final x0 = x(sel.$1), x1 = x(sel.$2);
      canvas.drawRect(Rect.fromLTRB(x0, ruler, max(x0 + 1, x1), h), fill..color = palette.selFill);
    }
    for (final (a, b) in deletes) {
      final x0 = x(a), x1 = x(b);
      if (x1 < 0 || x0 > w) continue;
      line.color = palette.cut;
      canvas
        ..drawLine(Offset(x0, ruler), Offset(x1, h), line)
        ..drawLine(Offset(x1, ruler), Offset(x0, h), line)
        ..drawRect(Rect.fromLTWH(x0, ruler, 1, h - ruler), fill..color = palette.cut)
        ..drawRect(Rect.fromLTWH(x1, ruler, 1, h - ruler), fill);
    }
    if (sel != null) {
      fill.color = palette.sel;
      canvas
        ..drawRect(Rect.fromLTWH(x(sel.$1) - 1, ruler, 2, h - ruler), fill)
        ..drawRect(Rect.fromLTWH(x(sel.$2) - 1, ruler, 2, h - ruler), fill);
    }
    fill.color = palette.split;
    for (final s in splits) {
      canvas.drawRect(Rect.fromLTWH(x(s) - 1, 0, 2, h), fill);
    }

    canvas.drawRect(Rect.fromLTWH(0, 0, w, ruler), fill..color = palette.waveBg);
    canvas.drawRect(Rect.fromLTWH(0, ruler - 1, w, 1), fill..color = palette.line);
    final step = niceStep(span, w);
    for (var t = (start / step).ceil() * step; t <= start + span; t += step) {
      final tx = x(t);
      canvas.drawRect(Rect.fromLTWH(tx, ruler - 6, 1, 6), fill..color = palette.line);
      final label = step < 1
          ? formatTime(t).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
          : formatTime(t, millis: false);
      final tp = TextPainter(
        text: TextSpan(text: label, style: TextStyle(color: palette.muted, fontSize: 11, fontFamily: 'monospace')),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(tx + 3, (ruler - tp.height) / 2));
    }

    canvas.drawRect(Rect.fromLTWH(x(playhead()) - 1, 0, 2, h), fill..color = palette.playhead);
  }

  @override
  bool shouldRepaint(WaveOverlayPainter old) => true;
}

/// Delete ranges, split points, the visible window and the playhead over the overview strip.
class OverviewOverlayPainter extends CustomPainter {
  OverviewOverlayPainter({
    required this.duration,
    required this.viewStart,
    required this.viewSpan,
    required this.deletes,
    required this.splits,
    required this.playhead,
    required this.palette,
    super.repaint,
  });

  final double duration, viewStart, viewSpan;
  final List<(double, double)> deletes;
  final List<double> splits;
  final double Function() playhead;
  final CutPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    if (duration <= 0) return;
    final w = size.width, h = size.height;
    double x(double t) => t / duration * w;
    final fill = Paint();
    for (final (a, b) in deletes) {
      canvas
        ..drawRect(Rect.fromLTRB(x(a), 0, max(x(a) + 1, x(b)), h), fill..color = palette.cutFill)
        ..drawRect(Rect.fromLTWH(x(a), 0, 1, h), fill..color = palette.cut);
    }
    fill.color = palette.split;
    for (final s in splits) {
      canvas.drawRect(Rect.fromLTWH(x(s) - 1, 0, 2, h), fill);
    }
    final v0 = x(viewStart), v1 = x(viewStart + viewSpan);
    canvas.drawRect(
      Rect.fromLTWH(v0 + 1, 1, max(4, v1 - v0 - 2), h - 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = palette.sel,
    );
    canvas.drawRect(Rect.fromLTWH(x(playhead()), 0, 1.5, h), fill..color = palette.playhead);
  }

  @override
  bool shouldRepaint(OverviewOverlayPainter old) => true;
}
