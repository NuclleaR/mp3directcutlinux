import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analysis/file_analysis.dart';
import '../ui/editor/view_window.dart';

const _unset = Object();

class EditorState {
  const EditorState({
    this.fileName,
    this.duration = 0,
    this.frameDuration = 0,
    this.frameCount = 0,
    this.view = const ViewWindow(0, 1),
    this.selection,
    this.cursor = 0,
    this.snapToSilence = true,
  });

  final String? fileName;
  final double duration;
  final double frameDuration;
  final int frameCount;
  final ViewWindow view;

  /// Selected time range in seconds, start < end.
  final (double, double)? selection;

  /// Where the last click on the wave landed, in seconds. Split uses the playhead.
  final double cursor;
  final bool snapToSilence;

  EditorState copyWith({ViewWindow? view, Object? selection = _unset, double? cursor, bool? snapToSilence}) =>
      EditorState(
        fileName: fileName,
        duration: duration,
        frameDuration: frameDuration,
        frameCount: frameCount,
        view: view ?? this.view,
        selection: identical(selection, _unset) ? this.selection : selection as (double, double)?,
        cursor: cursor ?? this.cursor,
        snapToSilence: snapToSilence ?? this.snapToSilence,
      );
}

class EditorController extends Notifier<EditorState> {
  @override
  EditorState build() => const EditorState();

  /// Shows [fileName] whole, with no selection; the snap setting carries over.
  void reset(String fileName, FileAnalysis analysis) {
    final layout = analysis.layout;
    final duration = layout.frameCount * layout.frameDuration;
    state = EditorState(
      fileName: fileName,
      duration: duration,
      frameDuration: layout.frameDuration,
      frameCount: layout.frameCount,
      view: ViewWindow(0, duration).clamp(duration),
      snapToSilence: state.snapToSilence,
    );
  }

  void setView(ViewWindow view) => state = state.copyWith(view: view.clamp(state.duration));

  void setSelection((double, double)? selection) => state = state.copyWith(selection: selection);

  void setCursor(double t) => state = state.copyWith(cursor: t.clamp(0, state.duration).toDouble());

  void toggleSnap() => state = state.copyWith(snapToSilence: !state.snapToSilence);

  void zoomIn() {
    final s = state.selection, v = state.view;
    final centre = s != null ? (s.$1 + s.$2) / 2 : v.start + v.span / 2;
    setView(v.zoomAt(centre, 0.5, state.duration));
  }

  void zoomOut() {
    final v = state.view;
    setView(v.zoomAt(v.start + v.span / 2, 2, state.duration));
  }

  void zoomFit() => setView(ViewWindow(0, state.duration));

  /// Shows `[a, b]` with some room around it (clicking a listed delete range).
  void zoomTo(double a, double b) {
    final pad = max(1.0, (b - a) * 0.5);
    setView(ViewWindow(a - pad, b - a + 2 * pad));
  }
}

final editorProvider = NotifierProvider<EditorController, EditorState>(EditorController.new);
