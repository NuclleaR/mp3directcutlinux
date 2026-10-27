import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/naming.dart';
import '../l10n/app_localizations.dart';
import '../state/apply_controller.dart';
import '../state/queue_controller.dart';
import '../state/queue_entry.dart';
import 'theme/cut_palette.dart';

String nameProblemText(AppLocalizations l, NameProblem p) => switch (p) {
      NameProblem.empty => l.nameEmpty,
      NameProblem.slash => l.nameSlash,
      NameProblem.tooLong => l.nameTooLong,
      NameProblem.duplicate => l.nameDuplicate,
    };

/// Queue size, the Apply button, progress and what the last Apply did.
class QueueBar extends ConsumerWidget {
  const QueueBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final palette = CutPalette.of(context);
    final queue = ref.watch(queueProvider);
    final apply = ref.watch(applyProvider);
    final pending = queue.entries.values.where((e) => e.hasWork && e.status != EntryStatus.done).length;
    final summary = apply.summary;

    final messages = <String>[
      for (final e in queue.entries.values)
        for (final r in e.results)
          if (r.result == OutputResult.conflict)
            l.conflictOutput(r.name)
          else if (r.result == OutputResult.written && !r.titleUpdated)
            l.titleNotUpdated(r.name)
          else if (r.result == OutputResult.error)
            '${r.name}: ${r.message ?? ''}',
      if (summary != null)
        for (final issues in summary.issues.values)
          for (final (name, problem) in issues) '$name: ${nameProblemText(l, problem)}',
    ];

    return Material(
      color: palette.panel,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (queue.brokenBackupName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l.queueFileBroken(queue.brokenBackupName!), style: TextStyle(color: palette.cut)),
              ),
            if (queue.saveError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l.queueSaveFailed(queue.saveError!), style: TextStyle(color: palette.cut)),
              ),
            Row(children: [
              Expanded(child: Text(l.queueCount(pending), overflow: TextOverflow.ellipsis)),
              if (apply.running) ...[
                SizedBox(width: 160, child: LinearProgressIndicator(value: apply.total == 0 ? null : apply.done / apply.total)),
                const SizedBox(width: 8),
                Text(l.applying(apply.done, apply.total)),
                const SizedBox(width: 12),
              ],
              FilledButton(
                onPressed: apply.running || pending == 0 ? null : () => ref.read(applyProvider.notifier).applyAll(),
                child: Text(l.apply),
              ),
            ]),
            if (summary != null) ...[
              const SizedBox(height: 6),
              Text(l.applyResults(summary.written, summary.conflicts, summary.errors, summary.skipped)),
              if (summary.obsolete.isNotEmpty)
                Text(l.obsoleteOutputs(summary.obsolete.join(', ')), style: TextStyle(color: palette.muted)),
            ],
            if (messages.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: ListView(
                  shrinkWrap: true,
                  children: [for (final m in messages) Text(m, style: TextStyle(color: palette.muted, fontSize: 13))],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
