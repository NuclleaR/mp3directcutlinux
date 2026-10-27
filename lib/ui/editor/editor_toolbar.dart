import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_format.dart';
import '../../l10n/app_localizations.dart';
import '../../state/editor_controller.dart';
import '../../state/playback_controller.dart';
import 'editor_shortcuts.dart';

const numberStyle = TextStyle(fontFamily: 'monospace', fontFeatures: [FontFeature.tabularFigures()]);

/// Play/pause, clock, zoom and the snap-to-silence switch.
class EditorToolbar extends ConsumerWidget {
  const EditorToolbar({super.key, required this.actions, required this.frame});

  final EditorActions actions;

  /// Ticks while playing, so the clock moves.
  final ValueListenable<int> frame;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final playing = ref.watch(playbackProvider.select((p) => p.playing));
    final snap = ref.watch(editorProvider.select((e) => e.snapToSilence));
    final editor = ref.read(editorProvider.notifier);
    return Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      FilledButton.tonal(onPressed: actions.togglePlay, child: Text(playing ? l.pause : l.play)),
      ValueListenableBuilder(
        valueListenable: frame,
        builder: (context, _, _) => Text(
          formatTime(ref.read(playbackProvider.notifier).position),
          style: numberStyle.copyWith(fontSize: 18),
        ),
      ),
      const SizedBox(width: 24),
      IconButton(tooltip: l.zoomOut, onPressed: editor.zoomOut, icon: const Icon(Icons.zoom_out)),
      IconButton(tooltip: l.zoomIn, onPressed: editor.zoomIn, icon: const Icon(Icons.zoom_in)),
      TextButton(onPressed: editor.zoomFit, child: Text(l.zoomFit)),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Checkbox(value: snap, onChanged: (_) => editor.toggleSnap()),
        Text(l.snapToSilence),
      ]),
    ]);
  }
}
