import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/apply/apply_runner.dart';
import 'folder_controller.dart';
import 'queue_controller.dart';
import 'queue_entry.dart';

class ApplySummary {
  const ApplySummary({
    required this.written,
    required this.conflicts,
    required this.errors,
    required this.skipped,
    required this.obsolete,
    required this.issues,
  });

  final int written, conflicts, errors, skipped;

  /// Earlier own outputs that this run no longer produced (left in `cut/`).
  final List<String> obsolete;

  /// Entries that were not applied because of their names.
  final Map<String, List<NameIssue>> issues;
}

class ApplyState {
  const ApplyState({this.running = false, this.done = 0, this.total = 0, this.summary});

  final bool running;
  final int done, total;
  final ApplySummary? summary;
}

class ApplyController extends Notifier<ApplyState> {
  @override
  ApplyState build() => const ApplyState();

  /// Applies every entry that has work, is not done, not stale and has valid names.
  Future<void> applyAll() async {
    final folder = ref.read(folderProvider);
    if (state.running || folder == null) return;
    final queue = ref.read(queueProvider);
    final pending = queue.entries.values.where((e) => e.hasWork && e.status != EntryStatus.done).toList();
    final fresh = {for (final e in pending) if (!queue.isStale(e.fileName)) e.fileName: e};
    final issues = validateQueue(fresh);
    final runnable = [for (final e in fresh.values) if (!issues.containsKey(e.fileName)) e];

    var written = 0, conflicts = 0, errors = 0;
    final obsolete = <String>[];
    state = ApplyState(running: true, total: runnable.length);
    for (final e in runnable) {
      QueueEntry result;
      try {
        result = await applyEntryInBackground(folder.dir.path, e);
      } catch (err) {
        result = e.copyWith(status: EntryStatus.error, results: [
          OutputRecord(name: e.fileName, result: OutputResult.error, titleUpdated: false, message: '$err'),
        ]);
      }
      // Saved per entry, so a crash mid-run never forgets which files this run wrote.
      ref.read(queueProvider.notifier).recordResult(e, result);
      await ref.read(queueProvider.notifier).flush();
      for (final r in result.results) {
        switch (r.result) {
          case OutputResult.written:
            written++;
          case OutputResult.conflict:
            conflicts++;
          case OutputResult.error:
            errors++;
          case OutputResult.skippedEmpty:
            break;
        }
      }
      obsolete.addAll(result.obsolete);
      state = ApplyState(running: true, done: state.done + 1, total: state.total);
    }
    state = ApplyState(
      done: state.done,
      total: state.total,
      summary: ApplySummary(
        written: written,
        conflicts: conflicts,
        errors: errors,
        skipped: pending.length - runnable.length,
        obsolete: obsolete,
        issues: issues,
      ),
    );
  }
}

final applyProvider = NotifierProvider<ApplyController, ApplyState>(ApplyController.new);
