import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/frame_range.dart';
import 'folder_controller.dart';
import 'queue_entry.dart';
import 'queue_store.dart';

class QueueState {
  const QueueState({this.entries = const {}, this.sources = const {}, this.brokenBackupName, this.saveError});

  final Map<String, QueueEntry> entries;

  /// The folder's MP3 files as last listed, by name.
  final Map<String, Mp3FileInfo> sources;
  final String? brokenBackupName;

  /// Why the last queue save failed; null once a save succeeds.
  final String? saveError;

  /// The source changed since the entry was made or last reviewed.
  bool isStale(String fileName) {
    final e = entries[fileName], s = sources[fileName];
    if (e == null || s == null) return false;
    return e.sourceSize != s.size || e.sourceMtimeMs != s.mtimeMs;
  }

  QueueState copyWith({Map<String, QueueEntry>? entries, Map<String, Mp3FileInfo>? sources, Object? saveError = _keep}) =>
      QueueState(
        entries: entries ?? this.entries,
        sources: sources ?? this.sources,
        brokenBackupName: brokenBackupName,
        saveError: saveError == _keep ? this.saveError : saveError as String?,
      );
}

const _keep = Object();

typedef _Marks = ({List<FrameRange> deletes, List<int> splits, String? outputName, Map<int, String> partNames});

class QueueController extends Notifier<QueueState> {
  Directory? _dir;
  Timer? _saveTimer;
  Future<void> _saving = Future.value();
  final _history = <String, List<_Marks>>{};

  @override
  QueueState build() {
    ref.onDispose(() => _saveTimer?.cancel());
    return const QueueState();
  }

  Future<void> load(Directory dir, List<Mp3FileInfo> files) async {
    _saveTimer?.cancel();
    _dir = dir;
    _history.clear();
    final loaded = await ref.read(queueStoreProvider).load(dir);
    state = QueueState(
      entries: loaded.entries,
      sources: {for (final f in files) f.name: f},
      brokenBackupName: loaded.brokenBackupName,
    );
  }

  void updateSources(List<Mp3FileInfo> files) =>
      state = state.copyWith(sources: {for (final f in files) f.name: f});

  void addDelete(String file, FrameRange range) =>
      _edit(file, (e) => e.copyWith(deletes: normalizeRanges([...e.deletes, range])));

  void removeDelete(String file, int index) =>
      _edit(file, (e) => e.copyWith(deletes: [...e.deletes]..removeAt(index)));

  void addSplit(String file, int frame, int frameCount) {
    final current = state.entries[file]?.splits ?? const [];
    if (frame <= 0 || frame >= frameCount || current.contains(frame)) return;
    _edit(file, (e) => e.copyWith(splits: [...e.splits, frame]..sort()));
  }

  void removeSplit(String file, int frame) =>
      _edit(file, (e) => e.copyWith(splits: [...e.splits]..remove(frame)));

  void setOutputName(String file, String? name) => _edit(file, (e) => e.copyWith(outputName: _clean(name)));

  void setPartName(String file, int anchor, String? name) => _edit(file, (e) {
        final names = {...e.partNames};
        final clean = _clean(name);
        if (clean == null) {
          names.remove(anchor);
        } else {
          names[anchor] = clean;
        }
        return e.copyWith(partNames: names);
      });

  bool canUndo(String file) => _history[file]?.isNotEmpty ?? false;

  void undo(String file) {
    final stack = _history[file];
    if (stack == null || stack.isEmpty) return;
    final m = stack.removeLast();
    _put(_entryFor(file).copyWith(
      deletes: m.deletes,
      splits: m.splits,
      outputName: m.outputName,
      partNames: m.partNames,
      status: EntryStatus.pending,
    ));
  }

  /// The user looked at a stale entry: accept the source as it is now.
  void clearStale(String file) {
    final e = state.entries[file], s = state.sources[file];
    if (e == null || s == null) return;
    _put(e.copyWith(sourceSize: s.size, sourceMtimeMs: s.mtimeMs));
  }

  /// Replaces entries wholesale; no undo history.
  void replaceEntries(Map<String, QueueEntry> entries) {
    state = state.copyWith(entries: {...state.entries, ...entries});
    _scheduleSave();
  }

  /// Stores what Apply made of [snapshot]. Marks changed while it ran win: the entry keeps
  /// them and stays pending, but still learns which files this run wrote.
  void recordResult(QueueEntry snapshot, QueueEntry result) {
    final current = _entryFor(result.fileName);
    final unchanged = listEquals(current.deletes, snapshot.deletes) &&
        listEquals(current.splits, snapshot.splits) &&
        current.outputName == snapshot.outputName &&
        mapEquals(current.partNames, snapshot.partNames);
    replaceEntries({
      result.fileName: unchanged
          ? result
          : current.copyWith(ownOutputs: result.ownOutputs, results: result.results, obsolete: result.obsolete),
    });
  }

  Future<void> flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    return _save();
  }

  QueueEntry _entryFor(String file) {
    final s = state.sources[file];
    return state.entries[file] ?? QueueEntry(fileName: file, sourceSize: s?.size ?? 0, sourceMtimeMs: s?.mtimeMs ?? 0);
  }

  void _edit(String file, QueueEntry Function(QueueEntry) change) {
    final before = _entryFor(file);
    (_history[file] ??= []).add(
        (deletes: before.deletes, splits: before.splits, outputName: before.outputName, partNames: before.partNames));
    _put(change(before).copyWith(status: EntryStatus.pending));
  }

  void _put(QueueEntry e) {
    final entries = {...state.entries};
    if (!e.hasWork && e.ownOutputs.isEmpty) {
      entries.remove(e.fileName);
    } else {
      entries[e.fileName] = e;
    }
    state = state.copyWith(entries: entries);
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), _save);
  }

  /// Saves run one after another, each with the entries as they were when it was asked for.
  /// A failure never throws; it shows as [QueueState.saveError] until a save succeeds.
  Future<void> _save() {
    final dir = _dir, entries = state.entries, store = ref.read(queueStoreProvider);
    if (dir == null) return _saving;
    return _saving = _saving.then((_) async {
      String? error;
      try {
        await store.save(dir, entries);
      } catch (e) {
        error = '$e';
      }
      if (ref.mounted && dir == _dir && error != state.saveError) state = state.copyWith(saveError: error);
    });
  }

  static String? _clean(String? name) => name == null || name.trim().isEmpty ? null : name;
}

final queueProvider = NotifierProvider<QueueController, QueueState>(QueueController.new);
