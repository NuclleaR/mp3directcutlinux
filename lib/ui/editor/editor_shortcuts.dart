import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analysis/file_analysis.dart';
import '../../core/frame_range.dart';
import '../../core/snap.dart';
import '../../state/editor_controller.dart';
import '../../state/playback_controller.dart';
import '../../state/queue_controller.dart';

/// What the editor's buttons and keys do to the open file.
class EditorActions {
  EditorActions(this.ref, this.fileName, this.analysis);

  final WidgetRef ref;
  final String fileName;
  final FileAnalysis analysis;

  EditorState get _ed => ref.read(editorProvider);
  EditorController get _editor => ref.read(editorProvider.notifier);
  QueueController get _queue => ref.read(queueProvider.notifier);

  void deleteSelection() {
    final s = _ed.selection, fd = _ed.frameDuration;
    if (s == null) return;
    _queue.addDelete(fileName, FrameRange((s.$1 / fd).round(), (s.$2 / fd).round()));
    _editor.setSelection(null);
  }

  /// Split at the playhead (a click on the wave moves it there), snapped like a new
  /// selection edge.
  void splitAtCursor() {
    final ed = _ed, rms = analysis.wave?.rms;
    final t = ref.read(playbackProvider.notifier).position;
    final k = ed.snapToSilence && rms != null
        ? snapToQuiet(t, rms, ed.frameDuration, ed.frameCount)
        : snapToFrame(t, ed.frameDuration, ed.frameCount);
    _queue.addSplit(fileName, k, ed.frameCount);
  }

  void undo() => _queue.undo(fileName);

  void clearSelection() => _editor.setSelection(null);

  Future<void> togglePlay() => ref.read(playbackProvider.notifier).togglePlay();

  Future<void> listenJoin(double a, double b) => ref.read(playbackProvider.notifier).listenJoin(a, b);
}

/// Keyboard shortcuts by physical key, so they work on any layout. They only fire while
/// the editor itself has focus, never while typing in one of its text fields.
class EditorShortcuts extends StatelessWidget {
  const EditorShortcuts({super.key, required this.actions, required this.focusNode, required this.child});

  final EditorActions actions;
  final FocusNode focusNode;
  final Widget child;

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent || FocusManager.instance.primaryFocus != node) return KeyEventResult.ignored;
    final k = e.physicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final editor = actions.ref.read(editorProvider.notifier);
    if (k == PhysicalKeyboardKey.space) {
      actions.togglePlay();
    } else if (k == PhysicalKeyboardKey.delete || k == PhysicalKeyboardKey.backspace) {
      actions.deleteSelection();
    } else if (k == PhysicalKeyboardKey.keyZ && ctrl) {
      actions.undo();
    } else if (k == PhysicalKeyboardKey.escape) {
      actions.clearSelection();
    } else if (k == PhysicalKeyboardKey.equal || k == PhysicalKeyboardKey.numpadAdd) {
      editor.zoomIn();
    } else if (k == PhysicalKeyboardKey.minus || k == PhysicalKeyboardKey.numpadSubtract) {
      editor.zoomOut();
    } else if (k == PhysicalKeyboardKey.digit0 || k == PhysicalKeyboardKey.numpad0) {
      editor.zoomFit();
    } else if (k == PhysicalKeyboardKey.keyS && !ctrl) {
      actions.splitAtCursor();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) =>
      Focus(focusNode: focusNode, autofocus: true, onKeyEvent: _onKey, child: child);
}
