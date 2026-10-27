import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../state/apply_controller.dart';
import '../state/queue_controller.dart';
import '../state/queue_entry.dart';
import 'theme/cut_palette.dart';

/// Shown after Apply when outputs of [files] hit foreign files in `cut/`: each file is
/// either overwritten or has its changes reset. Closes once none is left.
class ConflictDialog extends ConsumerWidget {
  const ConflictDialog({super.key, required this.files});

  final List<String> files;

  void _closeIfSettled(BuildContext context, WidgetRef ref) {
    final entries = ref.read(queueProvider).entries;
    if (files.every((f) => entries[f]?.status != EntryStatus.conflict)) Navigator.pop(context);
  }

  void _discard(BuildContext context, WidgetRef ref, String file) {
    ref.read(applyProvider.notifier).discard(file);
    _closeIfSettled(context, ref);
  }

  Future<void> _overwrite(BuildContext context, WidgetRef ref, QueueEntry entry) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.overwriteTitle),
        content: Text(l.overwriteBody(entry.conflictingOutputs.join(', '))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.overwrite)),
        ],
      ),
    );
    if (!(ok ?? false) || !context.mounted) return;
    await ref.read(applyProvider.notifier).overwrite(entry.fileName);
    if (context.mounted) _closeIfSettled(context, ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final palette = CutPalette.of(context);
    final entries = ref.watch(queueProvider).entries;
    final busy = ref.watch(applyProvider.select((a) => a.running));
    final open = [
      for (final f in files)
        if (entries[f] case final e? when e.status == EntryStatus.conflict) e,
    ];

    return AlertDialog(
      title: Text(l.conflictsTitle),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.conflictsBody),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final e in open)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e.fileName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            for (final n in e.conflictingOutputs)
                              Text(n, style: TextStyle(color: palette.muted, fontSize: 13)),
                          ]),
                        ),
                        TextButton(
                          onPressed: busy ? null : () => _discard(context, ref, e.fileName),
                          child: Text(l.discardChanges),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: busy ? null : () => _overwrite(context, ref, e),
                          child: Text(l.overwrite),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: Text(l.close)),
      ],
    );
  }
}
