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
    required this.conflicted,
  });

  final int written, conflicts, errors, skipped;

  /// Earlier own outputs that this run no longer produced (left in `cut/`).
  final List<String> obsolete;

  /// Entries that were not applied because of their names.
  final Map<String, List<NameIssue>> issues;

  /// Source files whose conflicts in `cut/` are not settled yet.
  final List<String> conflicted;
}

class ApplyState {
  const ApplyState({this.running = false, this.done = 0, this.total = 0, this.summary});

  final bool running;
  final int done, total;
  final ApplySummary? summary;
}

typedef _Tally = ({int written, int conflicts, int errors});

_Tally _tally(Iterable<OutputRecord> results) => (
      written: results.where((r) => r.result == OutputResult.written).length,
      conflicts: results.where((r) => r.result == OutputResult.conflict).length,
      errors: results.where((r) => r.result == OutputResult.error).length,
    );

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
    final obsolete = <String>[], conflicted = <String>[];
    state = ApplyState(running: true, total: runnable.length);
    for (final e in runnable) {
      final result = await _run(folder.dir.path, e);
      final t = _tally(result.results);
      written += t.written;
      conflicts += t.conflicts;
      errors += t.errors;
      if (t.conflicts > 0) conflicted.add(e.fileName);
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
        conflicted: conflicted,
      ),
    );
  }

  /// Writes [file] again, replacing the foreign files in `cut/` it last conflicted with.
  Future<void> overwrite(String file) async {
    final folder = ref.read(folderProvider);
    final before = ref.read(queueProvider).entries[file];
    if (state.running || folder == null || before == null || before.status != EntryStatus.conflict) return;
    state = ApplyState(running: true, total: 1, summary: state.summary);
    final after = await _run(folder.dir.path, before, overwrite: before.conflictingOutputs.toSet());
    state = ApplyState(done: 1, total: 1, summary: _settled(file, before.results, after.results));
  }

  /// Drops [file]'s marks; the foreign files in `cut/` it conflicted with stay as they are.
  void discard(String file) {
    final before = ref.read(queueProvider).entries[file];
    if (state.running || before == null) return;
    ref.read(queueProvider.notifier).discard(file);
    final kept = [for (final r in before.results) if (r.result != OutputResult.conflict) r];
    state = ApplyState(done: state.done, total: state.total, summary: _settled(file, before.results, kept));
  }

  Future<QueueEntry> _run(String folderPath, QueueEntry e, {Set<String> overwrite = const {}}) async {
    QueueEntry result;
    try {
      result = await applyEntryInBackground(folderPath, e, overwrite: overwrite);
    } catch (err) {
      result = e.copyWith(status: EntryStatus.error, results: [
        OutputRecord(name: e.fileName, result: OutputResult.error, titleUpdated: false, message: '$err'),
      ]);
    }
    // Saved per entry, so a crash mid-run never forgets which files this run wrote.
    ref.read(queueProvider.notifier).recordResult(e, result);
    await ref.read(queueProvider.notifier).flush();
    return result;
  }

  /// The last summary with [file]'s results [before] replaced by [after].
  ApplySummary? _settled(String file, List<OutputRecord> before, List<OutputRecord> after) {
    final s = state.summary;
    if (s == null) return null;
    final b = _tally(before), a = _tally(after);
    return ApplySummary(
      written: s.written + a.written - b.written,
      conflicts: s.conflicts + a.conflicts - b.conflicts,
      errors: s.errors + a.errors - b.errors,
      skipped: s.skipped,
      obsolete: s.obsolete,
      issues: s.issues,
      conflicted: [for (final f in s.conflicted) if (f != file || a.conflicts > 0) f],
    );
  }
}

final applyProvider = NotifierProvider<ApplyController, ApplyState>(ApplyController.new);
