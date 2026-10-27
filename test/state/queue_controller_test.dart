import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/core/frame_range.dart';
import 'package:mp3_direct_cut/state/folder_controller.dart';
import 'package:mp3_direct_cut/state/queue_controller.dart';
import 'package:mp3_direct_cut/state/queue_entry.dart';

void main() {
  late Directory dir;
  late ProviderContainer c;
  const f = 'Казка 2.mp3';

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('queue_ctl');
    File('test/fixtures/cbr_stereo_44k.mp3').copySync('${dir.path}/$f');
    File('test/fixtures/plain_cbr.mp3').copySync('${dir.path}/Казка 10.mp3');
    File('test/fixtures/vbr_mono_22k.mp3').copySync('${dir.path}/b.MP3');
    File('${dir.path}/notes.txt').writeAsStringSync('x');
    Directory('${dir.path}/sub').createSync();
    File('test/fixtures/plain_cbr.mp3').copySync('${dir.path}/sub/inner.mp3');
    c = ProviderContainer();
    await c.read(folderProvider.notifier).open(dir.path);
  });
  tearDown(() {
    c.dispose();
    dir.deleteSync(recursive: true);
  });

  QueueController q() => c.read(queueProvider.notifier);
  QueueEntry? e() => c.read(queueProvider).entries[f];

  test('folder lists only top-level mp3, natural order', () {
    expect(c.read(folderProvider)!.files.map((x) => x.name), ['b.MP3', 'Казка 2.mp3', 'Казка 10.mp3']);
  });

  test('deletes merge', () {
    q().addDelete(f, const FrameRange(10, 20));
    q().addDelete(f, const FrameRange(15, 30));
    expect(e()!.deletes, const [FrameRange(10, 30)]);
  });

  test('splits are validated and sorted', () {
    for (final s in [0, 383, 200, 100, 100, 999]) {
      q().addSplit(f, s, 383);
    }
    expect(e()!.splits, [100, 200]);
    q().removeSplit(f, 100);
    expect(e()!.splits, [200]);
  });

  test('blank names are stored as null', () {
    q().setOutputName(f, 'Збірка');
    q().setPartName(f, 0, 'Колобок');
    expect([e()!.outputName, e()!.partNames], ['Збірка', {0: 'Колобок'}]);
    q().setPartName(f, 0, '  ');
    q().setOutputName(f, '');
    expect(e(), isNull);
  });

  test('undo restores marks and names', () {
    q().addDelete(f, const FrameRange(10, 20));
    q().addSplit(f, 100, 383);
    q().setOutputName(f, 'X');
    q().undo(f);
    expect(e()!.outputName, isNull);
    q().undo(f);
    expect(e()!.splits, isEmpty);
    expect(q().canUndo(f), isTrue);
    q().undo(f);
    expect(e(), isNull);
    expect(q().canUndo(f), isFalse);
  });

  test('editing a done entry makes it pending', () {
    q().addDelete(f, const FrameRange(10, 20));
    q().replaceEntries({f: e()!.copyWith(status: EntryStatus.done)});
    q().addSplit(f, 100, 383);
    expect(e()!.status, EntryStatus.pending);
  });

  test('entry without work disappears unless it has own outputs', () {
    q().addDelete(f, const FrameRange(10, 20));
    q().removeDelete(f, 0);
    expect(e(), isNull);
    q().addDelete(f, const FrameRange(10, 20));
    q().replaceEntries({f: e()!.copyWith(ownOutputs: const [OwnOutput(name: 'a.mp3', size: 1, mtimeMs: 1)])});
    q().removeDelete(f, 0);
    expect(e(), isNotNull);
    expect(e()!.hasWork, isFalse);
  });

  test('clearing the queue drops unfinished work, keeps done entries and own outputs', () {
    const done = 'Казка 10.mp3', failed = 'b.MP3';
    q().addDelete(f, const FrameRange(10, 20));
    q().setOutputName(f, 'Ріпка');
    q().addSplit(done, 100, 383);
    q().replaceEntries({done: c.read(queueProvider).entries[done]!.copyWith(status: EntryStatus.done)});
    q().addDelete(failed, const FrameRange(10, 20));
    q().replaceEntries({
      failed: c.read(queueProvider).entries[failed]!.copyWith(
        status: EntryStatus.error,
        ownOutputs: const [OwnOutput(name: 'b.mp3', size: 1, mtimeMs: 1)],
        results: const [OutputRecord(name: 'b.mp3', result: OutputResult.error, titleUpdated: false, message: 'x')],
      ),
    });

    q().clearUnfinished();

    final entries = c.read(queueProvider).entries;
    expect(entries[f], isNull);
    expect(q().canUndo(f), isFalse);
    expect(entries[done]!.status, EntryStatus.done);
    expect(entries[done]!.splits, [100]);
    expect(entries[failed]!.hasWork, isFalse);
    expect(entries[failed]!.ownOutputs.map((o) => o.name), ['b.mp3']);
    expect(entries[failed]!.results, isEmpty);
  });

  test('discard drops one file\'s marks and keeps what it wrote', () {
    const other = 'b.MP3', bare = 'Казка 10.mp3';
    q().addDelete(f, const FrameRange(10, 20));
    q().replaceEntries({
      f: e()!.copyWith(
        status: EntryStatus.conflict,
        ownOutputs: const [OwnOutput(name: 'Казка 2 part 1.mp3', size: 1, mtimeMs: 1)],
        results: const [OutputRecord(name: 'Казка 2 part 2.mp3', result: OutputResult.conflict, titleUpdated: false)],
      ),
    });
    q().addDelete(other, const FrameRange(10, 20));
    q().setOutputName(bare, 'Ріпка');

    q().discard(f);
    q().discard(bare);

    final entries = c.read(queueProvider).entries;
    expect(entries[f]!.hasWork, isFalse);
    expect(entries[f]!.status, EntryStatus.pending);
    expect(entries[f]!.results, isEmpty);
    expect(entries[f]!.ownOutputs.map((o) => o.name), ['Казка 2 part 1.mp3']);
    expect(q().canUndo(f), isFalse);
    expect(entries[bare], isNull);
    expect(entries[other]!.deletes, isNotEmpty);
  });

  test('persists and reloads', () async {
    q().addDelete(f, const FrameRange(10, 20));
    q().setPartName(f, 0, 'Колобок');
    await q().flush();
    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    await c2.read(folderProvider.notifier).open(dir.path);
    expect(c2.read(queueProvider).entries[f]!.toJson(), e()!.toJson());
  });

  test('stale after the source changes; clearStale fixes it', () async {
    q().addDelete(f, const FrameRange(10, 20));
    expect(c.read(queueProvider).isStale(f), isFalse);
    File('${dir.path}/$f').setLastModifiedSync(DateTime(2001));
    await c.read(folderProvider.notifier).refresh();
    expect(c.read(queueProvider).isStale(f), isTrue);
    q().clearStale(f);
    expect(c.read(queueProvider).isStale(f), isFalse);
  });

  test('a broken queue file is reported', () async {
    File('${dir.path}/.mp3directcut-queue.json').writeAsStringSync('{oops');
    await c.read(folderProvider.notifier).open(dir.path);
    expect(c.read(queueProvider).brokenBackupName, startsWith('.mp3directcut-queue.broken-'));
  });
}
