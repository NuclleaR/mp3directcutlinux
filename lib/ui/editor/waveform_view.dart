import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analysis/file_analysis.dart';
import '../../core/snap.dart';
import '../../state/editor_controller.dart';
import '../../state/queue_controller.dart';
import '../theme/cut_palette.dart';
import 'wave_painter.dart';

/// Delete ranges and split points of the open file, in seconds.
({List<(double, double)> deletes, List<double> splits}) marksInSeconds(WidgetRef ref) {
  final editor = ref.watch(editorProvider);
  final entry = ref.watch(queueProvider.select((q) => q.entries[editor.fileName]));
  final fd = editor.frameDuration;
  return (
    deletes: [for (final r in entry?.deletes ?? const []) (r.start * fd, r.end * fd)],
    splits: [for (final s in entry?.splits ?? const <int>[]) s * fd],
  );
}

enum _DragMode { create, edge }

class _Drag {
  _Drag.create(this.x0, this.t0) : mode = _DragMode.create;
  _Drag.edge(this.edge) : mode = _DragMode.edge;

  final _DragMode mode;
  double x0 = 0, t0 = 0;
  int edge = 0;
  bool moved = false;
}

/// The main waveform: drag to select, drag an edge to adjust, click to place the cursor,
/// wheel to zoom, Shift+wheel to scroll.
class WaveformView extends ConsumerStatefulWidget {
  const WaveformView({super.key, required this.analysis, required this.playhead, required this.onSeek, this.repaint});

  static const height = 230.0;
  static const ruler = 22.0;

  final FileAnalysis analysis;
  final double Function() playhead;
  final ValueChanged<double> onSeek;

  /// Ticks while playing, so the playhead moves.
  final Listenable? repaint;

  @override
  ConsumerState<WaveformView> createState() => _WaveformViewState();
}

class _WaveformViewState extends ConsumerState<WaveformView> {
  _Drag? _drag;
  MouseCursor _cursor = SystemMouseCursors.text;

  EditorState get _editor => ref.read(editorProvider);
  EditorController get _ctl => ref.read(editorProvider.notifier);

  bool _nearEdge(double x, double width, double t) => (_editor.view.tToX(t, width) - x).abs() <= 7;

  void _hover(double x, double width) {
    final sel = _editor.selection;
    final near = sel != null && (_nearEdge(x, width, sel.$1) || _nearEdge(x, width, sel.$2));
    final cursor = near ? SystemMouseCursors.resizeLeftRight : SystemMouseCursors.text;
    if (cursor != _cursor) setState(() => _cursor = cursor);
  }

  void _down(PointerDownEvent e, double width) {
    if (e.buttons & kPrimaryButton == 0) return;
    final x = e.localPosition.dx;
    final sel = _editor.selection;
    if (sel != null && _nearEdge(x, width, sel.$1)) {
      _drag = _Drag.edge(0);
    } else if (sel != null && _nearEdge(x, width, sel.$2)) {
      _drag = _Drag.edge(1);
    } else {
      _drag = _Drag.create(x, _editor.view.xToT(x, width));
    }
  }

  void _move(PointerMoveEvent e, double width) {
    final d = _drag;
    if (d == null) return;
    final x = e.localPosition.dx;
    final t = _editor.view.xToT(x, width).clamp(0, _editor.duration).toDouble();
    if (d.mode == _DragMode.edge) {
      final s = [_editor.selection!.$1, _editor.selection!.$2];
      s[d.edge] = t;
      if (s[0] > s[1]) {
        s.setAll(0, [s[1], s[0]]);
        d.edge = 1 - d.edge;
      }
      _ctl.setSelection((s[0], s[1]));
    } else {
      if (!d.moved && (x - d.x0).abs() < 4) return;
      d.moved = true;
      _ctl.setSelection((min(d.t0, t), max(d.t0, t)));
    }
  }

  void _up() {
    final d = _drag;
    _drag = null;
    if (d == null) return;
    final ed = _editor;
    if (d.mode == _DragMode.create && !d.moved) {
      final t = d.t0.clamp(0, ed.duration).toDouble();
      _ctl
        ..setSelection(null)
        ..setCursor(t);
      widget.onSeek(t);
      return;
    }
    final sel = ed.selection;
    if (sel == null) return;
    final fd = ed.frameDuration, n = ed.frameCount;
    final rms = widget.analysis.wave?.rms;
    int snap(double t) => d.mode == _DragMode.create && ed.snapToSilence && rms != null
        ? snapToQuiet(t, rms, fd, n)
        : snapToFrame(t, fd, n);
    final a = snap(sel.$1) * fd, b = snap(sel.$2) * fd;
    _ctl.setSelection(b - a < fd / 2 ? null : (a, b));
  }

  void _signal(PointerSignalEvent e, double width) {
    if (e is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (event) {
      final s = event as PointerScrollEvent;
      final ed = _editor, v = ed.view;
      final dx = s.scrollDelta.dx, dy = s.scrollDelta.dy;
      final shift = HardwareKeyboard.instance.isShiftPressed;
      if (shift || dx.abs() > dy.abs()) {
        final delta = shift ? (dy != 0 ? dy : dx) : dx;
        _ctl.setView(v.pan(delta / width * v.span, ed.duration));
      } else {
        _ctl.setView(v.zoomAt(v.xToT(s.localPosition.dx, width), exp(dy * 0.0025), ed.duration));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = CutPalette.of(context);
    final editor = ref.watch(editorProvider);
    final marks = marksInSeconds(ref);
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final size = Size(width, WaveformView.height);
      return MouseRegion(
        cursor: _cursor,
        onHover: (e) => _hover(e.localPosition.dx, width),
        child: Listener(
          onPointerDown: (e) => _down(e, width),
          onPointerMove: (e) => _move(e, width),
          onPointerUp: (_) => _up(),
          onPointerCancel: (_) => _drag = null,
          onPointerSignal: (e) => _signal(e, width),
          child: SizedBox.fromSize(
            size: size,
            child: Stack(children: [
              RepaintBoundary(
                child: CustomPaint(
                  size: size,
                  painter: WaveLayerPainter(
                    wave: widget.analysis.wave,
                    start: editor.view.start,
                    span: editor.view.span,
                    palette: palette,
                    top: WaveformView.ruler,
                  ),
                ),
              ),
              CustomPaint(
                size: size,
                painter: WaveOverlayPainter(
                  start: editor.view.start,
                  span: editor.view.span,
                  deletes: marks.deletes,
                  splits: marks.splits,
                  selection: editor.selection,
                  playhead: widget.playhead,
                  palette: palette,
                  ruler: WaveformView.ruler,
                  repaint: widget.repaint,
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }
}
