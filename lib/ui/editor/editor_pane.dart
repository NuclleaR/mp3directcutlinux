import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analysis/file_analysis.dart';
import '../../core/mp3/parts.dart';
import '../../core/naming.dart';
import '../../core/time_format.dart';
import '../../l10n/app_localizations.dart';
import '../../state/editor_controller.dart';
import '../../state/playback_controller.dart';
import '../../state/queue_controller.dart';
import '../../state/selection_controller.dart';
import '../queue_bar.dart';
import '../theme/cut_palette.dart';
import 'deletes_list.dart';
import 'editor_shortcuts.dart';
import 'editor_toolbar.dart';
import 'name_field.dart';
import 'overview_strip.dart';
import 'parts_list.dart';
import 'selection_bar.dart';
import 'waveform_view.dart';

/// Everything for the open file, in the original page's order: toolbar, waveform and
/// overview, selection bar, lists, totals, hints.
class EditorPane extends ConsumerStatefulWidget {
  const EditorPane({super.key, required this.fileName, required this.path});

  final String fileName;
  final String path;

  @override
  ConsumerState<EditorPane> createState() => _EditorPaneState();
}

class _EditorPaneState extends ConsumerState<EditorPane> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _frame = ValueNotifier(0);
  final _focus = FocusNode(debugLabel: 'editor');
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      ref.read(playbackProvider.notifier).tick();
      _frame.value++;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _prepare(FileAnalysis a) {
    if (_ready) return;
    _ready = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(editorProvider.notifier).reset(widget.fileName, a);
      ref.read(playbackProvider.notifier).openFile(widget.path).catchError((Object e) {
        debugPrint('Cannot open ${widget.path} for playback: $e');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    ref.listen(playbackProvider.select((p) => p.playing), (_, playing) {
      if (playing && !_ticker.isActive) _ticker.start();
      if (!playing && _ticker.isActive) {
        _ticker.stop();
        _frame.value++;
      }
    });
    return ref.watch(fileAnalysisProvider(widget.path)).when(
          loading: () => Center(child: Text(l.drawingWave)),
          error: (e, _) => Center(child: Text('$e')),
          data: (a) {
            if (a.layout.frameCount == 0) return Center(child: Text(l.notMp3));
            _prepare(a);
            if (ref.watch(editorProvider.select((e) => e.fileName)) != widget.fileName) return const SizedBox.shrink();
            return _content(context, a);
          },
        );
  }

  Widget _content(BuildContext context, FileAnalysis a) {
    final l = AppLocalizations.of(context);
    final palette = CutPalette.of(context);
    final actions = EditorActions(ref, widget.fileName, a);
    final entry = ref.watch(queueProvider.select((q) => q.entries[widget.fileName]));
    final fd = a.layout.frameDuration;
    final parts = planParts(a.layout, entry?.deletes ?? const [], entry?.splits ?? const []);
    final playback = ref.read(playbackProvider.notifier);
    double playhead() => playback.position;

    void seek(double t) {
      playback.seek(t).whenComplete(() => _frame.value++);
    }

    return EditorShortcuts(
      actions: actions,
      focusNode: _focus,
      child: Listener(
        onPointerDown: (_) => _focus.requestFocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 10, children: [
            Row(children: [
              Expanded(child: Text(widget.fileName, style: Theme.of(context).textTheme.titleLarge)),
              if (entry == null || entry.splits.isEmpty)
                SizedBox(
                  width: 320,
                  child: NameField(
                    key: const ValueKey('output-name'),
                    value: entry?.outputName,
                    hint: sourceBase(widget.fileName),
                    label: l.outputName,
                    error: _problem(l, entry?.outputName),
                    onCommit: (v) => ref.read(queueProvider.notifier).setOutputName(widget.fileName, v),
                  ),
                ),
            ]),
            EditorToolbar(actions: actions, frame: _frame),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: DecoratedBox(
                decoration: BoxDecoration(border: Border.all(color: palette.line)),
                child: Column(children: [
                  Stack(children: [
                    WaveformView(analysis: a, playhead: playhead, onSeek: seek, repaint: _frame),
                    if (a.wave == null)
                      Positioned.fill(
                        top: WaveformView.ruler,
                        child: IgnorePointer(
                          child: Center(child: Text(l.waveFailed, style: TextStyle(color: palette.muted))),
                        ),
                      ),
                  ]),
                  Divider(height: 1, color: palette.line),
                  OverviewStrip(analysis: a, playhead: playhead, repaint: _frame),
                ]),
              ),
            ),
            SelectionBar(actions: actions),
            DeletesList(actions: actions),
            if (parts.length > 1) PartsList(fileName: widget.fileName, parts: parts, frameDuration: fd),
            Row(children: [
              Text(
                l.durations(
                  formatTime(a.layout.frameCount * fd, millis: false),
                  formatTime(keptFrameTotal(parts) * fd, millis: false),
                ),
                style: TextStyle(color: palette.muted),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: ref.read(queueProvider.notifier).canUndo(widget.fileName) ? actions.undo : null,
                child: Text(l.undo),
              ),
            ]),
            DefaultTextStyle.merge(
              style: TextStyle(color: palette.muted, fontSize: 13),
              child: Wrap(spacing: 16, runSpacing: 4, children: [
                Text(l.hintDrag),
                Text(l.hintEdge),
                Text(l.hintClick),
                Text(l.hintWheel),
                Text(l.hintKeys),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  String? _problem(AppLocalizations l, String? name) {
    if (name == null) return null;
    final p = checkName(name);
    return p == null ? null : nameProblemText(l, p);
  }
}
