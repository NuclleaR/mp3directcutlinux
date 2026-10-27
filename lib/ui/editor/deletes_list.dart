import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_format.dart';
import '../../l10n/app_localizations.dart';
import '../../state/editor_controller.dart';
import '../../state/queue_controller.dart';
import '../theme/cut_palette.dart';
import 'editor_shortcuts.dart';
import 'editor_toolbar.dart';
import 'selection_bar.dart';

/// "To be removed": every delete range of the open file.
class DeletesList extends ConsumerWidget {
  const DeletesList({super.key, required this.actions});

  final EditorActions actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final palette = CutPalette.of(context);
    final fd = ref.watch(editorProvider.select((e) => e.frameDuration));
    final deletes = ref.watch(queueProvider.select((q) => q.entries[actions.fileName]?.deletes)) ?? const [];
    final removed = deletes.fold(0.0, (sum, r) => sum + r.length * fd);
    return EditorPanel(
      title: l.deletesTitle,
      trailing: deletes.isEmpty ? null : l.deletesSummary(deletes.length, formatTime(removed)),
      children: deletes.isEmpty
          ? [Padding(padding: const EdgeInsets.all(12), child: Text(l.deletesEmpty, style: TextStyle(color: palette.muted)))]
          : [
              for (var i = 0; i < deletes.length; i++)
                _row(context, ref, i, deletes[i].start * fd, deletes[i].end * fd, l, palette),
            ],
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, int i, double a, double b, AppLocalizations l, CutPalette palette) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(children: [
          SizedBox(width: 28, child: Text('${i + 1}', style: numberStyle.copyWith(color: palette.cut))),
          Expanded(
            child: Tooltip(
              message: l.showOnWave,
              child: InkWell(
                onTap: () => ref.read(editorProvider.notifier).zoomTo(a, b),
                child: Text(rangeText(a, b), style: numberStyle),
              ),
            ),
          ),
          TextButton(onPressed: () => actions.listenJoin(a, b), child: Text(l.joinShort)),
          TextButton(
            onPressed: () => ref.read(queueProvider.notifier).removeDelete(actions.fileName, i),
            child: Text(l.restore),
          ),
        ]),
      );
}

/// A bordered box with a title row, used by the delete and parts lists.
class EditorPanel extends StatelessWidget {
  const EditorPanel({super.key, required this.title, required this.children, this.trailing});

  final String title;
  final String? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = CutPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.panel,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            if (trailing != null) Text(trailing!, style: numberStyle.copyWith(color: palette.muted)),
          ]),
        ),
        Divider(height: 1, color: palette.line),
        ...children,
      ]),
    );
  }
}
