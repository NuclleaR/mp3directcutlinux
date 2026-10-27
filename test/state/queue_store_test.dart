import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/core/frame_range.dart';
import 'package:mp3_direct_cut/state/queue_entry.dart';
import 'package:mp3_direct_cut/state/queue_store.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('queue_store'));
  tearDown(() => dir.deleteSync(recursive: true));

  final entry = QueueEntry(
    fileName: 'Казка 1.mp3',
    sourceSize: 1234,
    sourceMtimeMs: 99,
    deletes: const [FrameRange(10, 20), FrameRange(40, 50)],
    splits: const [100, 200],
    outputName: 'Збірка',
    partNames: const {0: 'Колобок', 200: 'Ріпка'},
    status: EntryStatus.conflict,
    ownOutputs: const [OwnOutput(name: 'Колобок.mp3', size: 10, mtimeMs: 5)],
    results: const [
      OutputRecord(name: 'Колобок.mp3', result: OutputResult.written, titleUpdated: true),
      OutputRecord(name: 'Збірка part 2.mp3', result: OutputResult.conflict, titleUpdated: false, message: 'x'),
    ],
    obsolete: const ['old.mp3'],
  );

  test('round-trips a full entry', () async {
    final store = QueueStore();
    await store.save(dir, {entry.fileName: entry});
    final loaded = await store.load(dir);
    expect(loaded.brokenBackupName, isNull);
    expect(loaded.entries[entry.fileName]!.toJson(), entry.toJson());
  });

  test('atomic save leaves no temp file', () async {
    await QueueStore().save(dir, {entry.fileName: entry});
    expect(dir.listSync().map((e) => e.uri.pathSegments.last), ['.mp3directcut-queue.json']);
  });

  test('missing file → empty queue', () async {
    final loaded = await QueueStore().load(dir);
    expect(loaded.entries, isEmpty);
    expect(loaded.brokenBackupName, isNull);
  });

  for (final (label, content) in [('unparsable', '{oops'), ('unknown version', '{"version": 2, "entries": {}}')]) {
    test('$label file is backed up, not overwritten', () async {
      File('${dir.path}/.mp3directcut-queue.json').writeAsStringSync(content);
      final loaded = await QueueStore().load(dir);
      expect(loaded.entries, isEmpty);
      expect(loaded.brokenBackupName, matches(RegExp(r'^\.mp3directcut-queue\.broken-\d{8}-\d{6}\.json$')));
      expect(File('${dir.path}/${loaded.brokenBackupName}').readAsStringSync(), content);
      expect(File('${dir.path}/.mp3directcut-queue.json').existsSync(), isFalse);
    });
  }
}
