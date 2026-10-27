import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_format.dart';
import '../../l10n/app_localizations.dart';
import '../../state/editor_controller.dart';
import '../theme/cut_palette.dart';
import 'editor_shortcuts.dart';
import 'editor_toolbar.dart';

String rangeText(double a, double b) => '${formatTime(a)} – ${formatTime(b)}  (${formatTime(b - a)})';

/// The current selection and what can be done with it.
class SelectionBar extends ConsumerWidget {
  const SelectionBar({super.key, required this.actions});

  final EditorActions actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final palette = CutPalette.of(context);
    final sel = ref.watch(editorProvider.select((e) => e.selection));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.panel,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(l.selectedLabel, style: TextStyle(color: palette.muted)),
          Text(sel == null ? l.selectionNone : rangeText(sel.$1, sel.$2), style: numberStyle),
          OutlinedButton(
            onPressed: sel == null ? null : () => actions.listenJoin(sel.$1, sel.$2),
            child: Text(l.listenJoin),
          ),
          OutlinedButton(
            onPressed: sel == null ? null : actions.deleteSelection,
            style: OutlinedButton.styleFrom(foregroundColor: palette.cut),
            child: Text(l.deleteSelection),
          ),
          OutlinedButton(
            onPressed: actions.splitAtCursor,
            style: OutlinedButton.styleFrom(foregroundColor: palette.split),
            child: Text(l.splitAtCursor),
          ),
        ]),
      ),
    );
  }
}
