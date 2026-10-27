import 'dart:io';
import 'dart:isolate';

import '../../state/queue_entry.dart';
import '../mp3/id3_title.dart';
import '../mp3/mp3_parser.dart';
import '../mp3/mp3_writer.dart';
import '../mp3/parts.dart';
import '../naming.dart';

typedef NameIssue = (String output, NameProblem problem);

/// Output names of [e], one per part (`[0, ...splits]`).
List<String> entryOutputNames(QueueEntry e) => namesForAnchors(
      sourceFileName: e.fileName,
      outputName: e.outputName,
      partNames: e.partNames,
      anchors: [0, ...e.splits],
    );

/// Bad names per entry, plus [NameProblem.duplicate] for any name that more than one
/// output in [entries] would get.
Map<String, List<NameIssue>> validateQueue(Map<String, QueueEntry> entries) {
  final names = {for (final e in entries.values) e.fileName: entryOutputNames(e)};
  final count = <String, int>{};
  for (final list in names.values) {
    for (final n in list) {
      count[n] = (count[n] ?? 0) + 1;
    }
  }
  final issues = <String, List<NameIssue>>{};
  names.forEach((file, list) {
    for (final n in list) {
      final problem = checkName(n) ?? (count[n]! > 1 ? NameProblem.duplicate : null);
      if (problem != null) (issues[file] ??= []).add((n, problem));
    }
  });
  return issues;
}

/// Writes every output of [entry] into `<folder>/cut/` and returns the entry with its new
/// status, own outputs and results. Never touches the source; never overwrites a file in
/// `cut/` that the app did not write for this entry, unless its name is in [overwrite].
QueueEntry applyEntrySync(Directory folder, QueueEntry entry, {Set<String> overwrite = const {}}) {
  QueueEntry failed(String message) => entry.copyWith(
        status: EntryStatus.error,
        results: [OutputRecord(name: entry.fileName, result: OutputResult.error, titleUpdated: false, message: message)],
        obsolete: const [],
      );

  final src = File('${folder.path}/${entry.fileName}');
  if (!src.existsSync()) return failed('source file not found');
  final stat = src.statSync();
  if (stat.size != entry.sourceSize || stat.modified.millisecondsSinceEpoch != entry.sourceMtimeMs) {
    return failed('source file changed');
  }
  final bytes = src.readAsBytesSync();
  final layout = parseMp3(bytes);
  if (layout.frameCount == 0) return failed('not an MP3');

  final parts = planParts(layout, entry.deletes, entry.splits);
  final names = outputNames(
    sourceFileName: entry.fileName,
    outputName: entry.outputName,
    partNames: entry.partNames,
    parts: parts,
  );
  final retitle = entry.outputName != null || entry.partNames.isNotEmpty || entry.splits.isNotEmpty;
  final cut = Directory('${folder.path}/cut')..createSync();
  final previous = {for (final o in entry.ownOutputs) o.name: o};
  final own = {...previous};
  final produced = <String>{};
  final results = <OutputRecord>[];

  for (final part in parts) {
    final name = names[part.index], file = '$name.mp3';
    if (part.isEmpty) {
      results.add(OutputRecord(name: file, result: OutputResult.skippedEmpty, titleUpdated: false));
      continue;
    }
    produced.add(file);
    final target = File('${cut.path}/$file');
    if (target.existsSync() && !overwrite.contains(file)) {
      final st = target.statSync(), mine = previous[file];
      if (mine == null || mine.size != st.size || mine.mtimeMs != st.modified.millisecondsSinceEpoch) {
        own.remove(file);
        results.add(OutputRecord(name: file, result: OutputResult.conflict, titleUpdated: false));
        continue;
      }
    }
    var head = layout.head, tail = layout.tail;
    var titleUpdated = true;
    if (retitle) {
      final t = id3v2WithTitle(layout.head, name);
      head = t.bytes;
      titleUpdated = t.updated;
      tail = id3v1WithTitle(layout.tail, name);
    }
    final data = buildOutput(bytes, layout, part.keep,
        head: head, tail: tail, keepEncoderDelay: part.startsAtSourceStart, keepEndPadding: part.endsAtSourceEnd);
    final tmp = File('${cut.path}/.$file.tmp');
    try {
      tmp.writeAsBytesSync(data, flush: true);
      tmp.renameSync(target.path);
      final st = target.statSync();
      own[file] = OwnOutput(name: file, size: st.size, mtimeMs: st.modified.millisecondsSinceEpoch);
      results.add(OutputRecord(name: file, result: OutputResult.written, titleUpdated: titleUpdated));
    } catch (e) {
      if (tmp.existsSync()) tmp.deleteSync();
      results.add(OutputRecord(name: file, result: OutputResult.error, titleUpdated: false, message: '$e'));
    }
  }

  final status = results.any((r) => r.result == OutputResult.error)
      ? EntryStatus.error
      : results.any((r) => r.result == OutputResult.conflict)
          ? EntryStatus.conflict
          : EntryStatus.done;
  return entry.copyWith(
    status: status,
    ownOutputs: own.values.toList(),
    results: results,
    obsolete: [for (final name in previous.keys) if (!produced.contains(name)) name],
  );
}

/// [applyEntrySync] in a background isolate.
Future<QueueEntry> applyEntryInBackground(String folderPath, QueueEntry entry, {Set<String> overwrite = const {}}) =>
    Isolate.run(() => applyEntrySync(Directory(folderPath), entry, overwrite: overwrite));
