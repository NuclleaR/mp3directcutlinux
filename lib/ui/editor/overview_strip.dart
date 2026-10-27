import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analysis/file_analysis.dart';
import '../../state/editor_controller.dart';
import '../theme/cut_palette.dart';
import 'view_window.dart';
import 'wave_painter.dart';
import 'waveform_view.dart';

/// The whole file at a glance; press or drag to move the visible window there.
class OverviewStrip extends ConsumerWidget {
  const OverviewStrip({super.key, required this.analysis, required this.playhead, this.repaint});

  static const height = 40.0;

  final FileAnalysis analysis;
  final double Function() playhead;
  final Listenable? repaint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = CutPalette.of(context);
    final editor = ref.watch(editorProvider);
    final marks = marksInSeconds(ref);
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final size = Size(width, height);
      void centre(Offset p) {
        final ed = ref.read(editorProvider);
        final t = p.dx / width * ed.duration;
        ref.read(editorProvider.notifier).setView(ViewWindow(t - ed.view.span / 2, ed.view.span));
      }

      return Listener(
        onPointerDown: (e) {
          if (e.buttons & kPrimaryButton != 0) centre(e.localPosition);
        },
        onPointerMove: (e) {
          if (e.buttons & kPrimaryButton != 0) centre(e.localPosition);
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: SizedBox.fromSize(
            size: size,
            child: Stack(children: [
              RepaintBoundary(
                child: CustomPaint(
                  size: size,
                  painter: WaveLayerPainter(
                    wave: analysis.wave,
                    start: 0,
                    span: editor.duration,
                    palette: palette,
                    opacity: 0.7,
                  ),
                ),
              ),
              CustomPaint(
                size: size,
                painter: OverviewOverlayPainter(
                  duration: editor.duration,
                  viewStart: editor.view.start,
                  viewSpan: editor.view.span,
                  deletes: marks.deletes,
                  splits: marks.splits,
                  playhead: playhead,
                  palette: palette,
                  repaint: repaint,
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }
}
