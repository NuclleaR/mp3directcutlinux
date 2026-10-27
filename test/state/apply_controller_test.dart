import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/core/frame_range.dart';
import 'package:mp3_direct_cut/state/apply_controller.dart';
import 'package:mp3_direct_cut/state/folder_controller.dart';
import 'package:mp3_direct_cut/state/queue_controller.dart';
import 'package:mp3_direct_cut/state/queue_entry.dart';
import 'package:mp3_direct_cut/state/queue_store.dart';

void main() {
  late Directory dir;
  late ProviderContainer c;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('apply_ctl');
    for (final n in ['a.mp3', 'b.mp3']) {
      File('test/fixtures/cbr_stereo_44k.mp3').copySync('${dir.path}/$n');
    }
    c = ProviderContainer();
    await c.read(folderProvider.notifier).open(dir.path);
  });
  tearDown(() {
    c.dispose();
    dir.deleteSync(recursive: true);
  });

  QueueController q() => c.read(queueProvider.notifier);
  Future<ApplySummary> apply() async {
    await c.read(applyProvider.notifier).applyAll();
    return c.read(applyProvider).summary!;
  }

  test('an invalid name is skipped, the other entry runs', () async {
    q().setOutputName('a.mp3', 'x/y');
    q().addDelete('b.mp3', const FrameRange(10, 20));
    final s = await apply();
    expect([s.written, s.skipped, s.conflicts, s.errors], [1, 1, 0, 0]);
    expect(s.issues['a.mp3'], isNotEmpty);
    expect(File('${dir.path}/cut/b.mp3').existsSync(), isTrue);
    expect(c.read(queueProvider).entries['b.mp3']!.status, EntryStatus.done);
  });

  test('done entries are skipped on the next Apply', () async {
    q().addDelete('a.mp3', const FrameRange(10, 20));
    await apply();
    final s = await apply();
    expect([s.written, s.skipped], [0, 0]);
    expect(c.read(applyProvider).total, 0);
  });

  test('stale entries are skipped', () async {
    q().addDelete('a.mp3', const FrameRange(10, 20));
    File('${dir.path}/a.mp3').setLastModifiedSync(DateTime(2001));
    await c.read(folderProvider.notifier).refresh();
    final s = await apply();
    expect([s.written, s.skipped], [0, 1]);
  });

  test('a missing source does not stop the next entry', () async {
    q().addDelete('a.mp3', const FrameRange(10, 20));
    q().addDelete('b.mp3', const FrameRange(10, 20));
    File('${dir.path}/a.mp3').deleteSync();
    final s = await apply();
    expect([s.written, s.errors], [1, 1]);
  });

  test('marks added while Apply runs are kept and the entry stays pending', () async {
    q().addDelete('a.mp3', const FrameRange(10, 20));
    q().addDelete('b.mp3', const FrameRange(10, 20));
    final run = c.read(applyProvider.notifier).applyAll();
    q().addDelete('b.mp3', const FrameRange(40, 50));
    await run;
    final b = c.read(queueProvider).entries['b.mp3']!;
    expect(b.deletes, const [FrameRange(10, 20), FrameRange(40, 50)]);
    expect(b.status, EntryStatus.pending);
    expect(b.ownOutputs.map((o) => o.name), ['b.mp3']);
    expect(c.read(queueProvider).entries['a.mp3']!.status, EntryStatus.done);
  });

  Future<ProviderContainer> withStore(QueueStore store) async {
    final c2 = ProviderContainer(overrides: [queueStoreProvider.overrideWithValue(store)]);
    addTearDown(c2.dispose);
    await c2.read(folderProvider.notifier).open(dir.path);
    return c2;
  }

  test('a failing queue save still ends Apply and is reported', () async {
    final c2 = await withStore(_FailingStore());
    c2.read(queueProvider.notifier).addDelete('a.mp3', const FrameRange(10, 20));
    await c2.read(applyProvider.notifier).applyAll();
    expect(c2.read(applyProvider).running, isFalse);
    expect(c2.read(applyProvider).summary!.written, 1);
    expect(c2.read(queueProvider).saveError, contains('No space left'));
  });

  test('queue saves never overlap and the last one wins', () async {
    final store = _RecordingStore();
    final c2 = await withStore(store);
    final queue = c2.read(queueProvider.notifier);
    queue.addDelete('a.mp3', const FrameRange(10, 20));
    final first = queue.flush();
    queue.addDelete('a.mp3', const FrameRange(40, 50));
    await Future.wait([first, queue.flush()]);
    expect(store.maxActive, 1);
    expect(store.saved.last['a.mp3']!.deletes, hasLength(2));
  });

  test('each applied entry is saved as soon as it is written', () async {
    final store = _RecordingStore();
    final c2 = await withStore(store);
    c2.read(queueProvider.notifier)
      ..addDelete('a.mp3', const FrameRange(10, 20))
      ..addDelete('b.mp3', const FrameRange(10, 20));
    await c2.read(applyProvider.notifier).applyAll();
    expect(
      store.saved.any((m) => m['a.mp3']?.status == EntryStatus.done && m['b.mp3']?.status == EntryStatus.pending),
      isTrue,
    );
  });

  test('results are saved to the queue file', () async {
    q().addDelete('a.mp3', const FrameRange(10, 20));
    await apply();
    final text = File('${dir.path}/.mp3directcut-queue.json').readAsStringSync();
    expect(text, contains('"status": "done"'));
  });
}

class _FailingStore extends QueueStore {
  @override
  Future<void> save(Directory folder, Map<String, QueueEntry> entries) async =>
      throw const FileSystemException('No space left on device');
}

class _RecordingStore extends QueueStore {
  final saved = <Map<String, QueueEntry>>[];
  int active = 0, maxActive = 0;

  @override
  Future<void> save(Directory folder, Map<String, QueueEntry> entries) async {
    active++;
    maxActive = max(maxActive, active);
    saved.add(entries);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    active--;
  }
}
