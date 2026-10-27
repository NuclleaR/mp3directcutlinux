import 'package:flutter/foundation.dart';

import '../core/frame_range.dart';

enum EntryStatus { pending, done, conflict, error }

enum OutputResult { written, conflict, error, skippedEmpty }

/// A file in `cut/` that the app wrote for an entry, as it was right after writing.
@immutable
class OwnOutput {
  const OwnOutput({required this.name, required this.size, required this.mtimeMs});

  factory OwnOutput.fromJson(Map<String, dynamic> j) =>
      OwnOutput(name: j['name'] as String, size: j['size'] as int, mtimeMs: j['mtimeMs'] as int);

  /// File name including `.mp3`.
  final String name;
  final int size;
  final int mtimeMs;

  Map<String, Object?> toJson() => {'name': name, 'size': size, 'mtimeMs': mtimeMs};
}

/// What the last Apply did with one output of an entry.
@immutable
class OutputRecord {
  const OutputRecord({required this.name, required this.result, required this.titleUpdated, this.message});

  factory OutputRecord.fromJson(Map<String, dynamic> j) => OutputRecord(
        name: j['name'] as String,
        result: OutputResult.values.byName(j['result'] as String),
        titleUpdated: j['titleUpdated'] as bool,
        message: j['message'] as String?,
      );

  final String name;
  final OutputResult result;
  final bool titleUpdated;
  final String? message;

  Map<String, Object?> toJson() =>
      {'name': name, 'result': result.name, 'titleUpdated': titleUpdated, 'message': message};
}

const _unset = Object();

/// Everything to do with one source file: one queue entry per file.
@immutable
class QueueEntry {
  const QueueEntry({
    required this.fileName,
    required this.sourceSize,
    required this.sourceMtimeMs,
    this.deletes = const [],
    this.splits = const [],
    this.outputName,
    this.partNames = const {},
    this.status = EntryStatus.pending,
    this.ownOutputs = const [],
    this.results = const [],
    this.obsolete = const [],
  });

  factory QueueEntry.fromJson(String fileName, Map<String, dynamic> j) => QueueEntry(
        fileName: fileName,
        sourceSize: j['size'] as int,
        sourceMtimeMs: j['mtimeMs'] as int,
        deletes: [for (final r in j['deletes'] as List) FrameRange.fromJson(r as List)],
        splits: [for (final s in j['splits'] as List) s as int],
        outputName: j['name'] as String?,
        partNames: {for (final e in (j['partNames'] as Map).entries) int.parse(e.key as String): e.value as String},
        status: EntryStatus.values.byName(j['status'] as String),
        ownOutputs: [for (final o in j['ownOutputs'] as List) OwnOutput.fromJson(o as Map<String, dynamic>)],
        results: [for (final r in j['results'] as List) OutputRecord.fromJson(r as Map<String, dynamic>)],
        obsolete: [for (final o in j['obsolete'] as List) o as String],
      );

  final String fileName;

  /// Size and modification time of the source when the entry was made or last reviewed.
  final int sourceSize;
  final int sourceMtimeMs;
  final List<FrameRange> deletes;

  /// Sorted, unique frame indices where a new part starts.
  final List<int> splits;

  /// File-level output name (no extension).
  final String? outputName;

  /// Part names keyed by the frame that starts the part (0 for the first part).
  final Map<int, String> partNames;
  final EntryStatus status;
  final List<OwnOutput> ownOutputs;
  final List<OutputRecord> results;

  /// Own outputs from earlier runs that the last Apply no longer produced.
  final List<String> obsolete;

  bool get hasWork => deletes.isNotEmpty || splits.isNotEmpty || outputName != null || partNames.isNotEmpty;

  /// Outputs the last Apply left alone because a foreign file in `cut/` has their name.
  List<String> get conflictingOutputs => [for (final r in results) if (r.result == OutputResult.conflict) r.name];

  QueueEntry copyWith({
    int? sourceSize,
    int? sourceMtimeMs,
    List<FrameRange>? deletes,
    List<int>? splits,
    Object? outputName = _unset,
    Map<int, String>? partNames,
    EntryStatus? status,
    List<OwnOutput>? ownOutputs,
    List<OutputRecord>? results,
    List<String>? obsolete,
  }) =>
      QueueEntry(
        fileName: fileName,
        sourceSize: sourceSize ?? this.sourceSize,
        sourceMtimeMs: sourceMtimeMs ?? this.sourceMtimeMs,
        deletes: deletes ?? this.deletes,
        splits: splits ?? this.splits,
        outputName: identical(outputName, _unset) ? this.outputName : outputName as String?,
        partNames: partNames ?? this.partNames,
        status: status ?? this.status,
        ownOutputs: ownOutputs ?? this.ownOutputs,
        results: results ?? this.results,
        obsolete: obsolete ?? this.obsolete,
      );

  Map<String, Object?> toJson() => {
        'size': sourceSize,
        'mtimeMs': sourceMtimeMs,
        'deletes': [for (final r in deletes) r.toJson()],
        'splits': splits,
        'name': outputName,
        'partNames': {for (final e in partNames.entries) '${e.key}': e.value},
        'status': status.name,
        'ownOutputs': [for (final o in ownOutputs) o.toJson()],
        'results': [for (final r in results) r.toJson()],
        'obsolete': obsolete,
      };
}
