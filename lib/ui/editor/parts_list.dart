import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/mp3/parts.dart';
import '../../core/naming.dart';
import '../../l10n/app_localizations.dart';
import '../../state/queue_controller.dart';
import '../queue_bar.dart';
import '../theme/cut_palette.dart';
import 'deletes_list.dart';
import 'editor_toolbar.dart';
import 'name_field.dart';
import 'selection_bar.dart';

/// One row per part of a split file: its time range and its own name.
class PartsList extends ConsumerWidget {
  const PartsList({super.key, required this.fileName, required this.parts, required this.frameDuration});

  final String fileName;
  final List<PartPlan> parts;
  final double frameDuration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final palette = CutPalette.of(context);
    final entry = ref.watch(queueProvider.select((q) => q.entries[fileName]));
    final defaults = outputNames(
      sourceFileName: fileName,
      outputName: entry?.outputName,
      partNames: const {},
      parts: parts,
    );
    final fd = frameDuration;
    return EditorPanel(title: l.partsTitle, children: [
      for (final part in parts)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            SizedBox(width: 28, child: Text('${part.index + 1}', style: numberStyle.copyWith(color: palette.split))),
            SizedBox(
              width: 300,
              child: Text(rangeText(part.startFrame * fd, part.endFrame * fd), style: numberStyle),
            ),
            Expanded(
              child: NameField(
                key: ValueKey('part-${part.anchorFrame}'),
                value: entry?.partNames[part.anchorFrame],
                defaultName: defaults[part.index],
                error: _problem(l, entry?.partNames[part.anchorFrame]),
                onCommit: (v) => ref.read(queueProvider.notifier).setPartName(fileName, part.anchorFrame, v),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              child: part.index == 0
                  ? null
                  : IconButton(
                      tooltip: l.removeSplit,
                      icon: const Icon(Icons.link_off),
                      onPressed: () => ref.read(queueProvider.notifier).removeSplit(fileName, part.anchorFrame),
                    ),
            ),
          ]),
        ),
    ]);
  }

  String? _problem(AppLocalizations l, String? name) {
    if (name == null) return null;
    final p = checkName(name);
    return p == null ? null : nameProblemText(l, p);
  }
}
