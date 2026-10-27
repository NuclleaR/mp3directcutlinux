import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/core/apply/apply_runner.dart';
import 'package:mp3_direct_cut/core/frame_range.dart';
import 'package:mp3_direct_cut/core/mp3/mp3_parser.dart';
import 'package:mp3_direct_cut/core/naming.dart';
import 'package:mp3_direct_cut/state/queue_entry.dart';

import '../../support/id3_reader.dart';

void main() {
  late Directory dir;
  const f = 'Казка.mp3';

  setUp(() {
    dir = Directory.systemTemp.createTempSync('apply');
    File('test/fixtures/cbr_stereo_44k.mp3').copySync('${dir.path}/$f');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  QueueEntry entry({List<FrameRange> deletes = const [], List<int> splits = const [], String? name}) {
    final st = File('${dir.path}/$f').statSync();
    return QueueEntry(
      fileName: f,
      sourceSize: st.size,
      sourceMtimeMs: st.modified.millisecondsSinceEpoch,
      deletes: deletes,
      splits: splits,
      outputName: name,
    );
  }

  File out(String name) => File('${dir.path}/cut/$name');

  test('deletes only → cut/Казка.mp3, original untouched, tags unchanged', () {
    final before = File('${dir.path}/$f').readAsBytesSync();
    final r = applyEntrySync(dir, entry(deletes: const [FrameRange(100, 200)]));
    expect(r.status, EntryStatus.done);
    expect(r.results.single.result, OutputResult.written);
    expect(File('${dir.path}/$f').readAsBytesSync(), before);
    final bytes = out('Казка.mp3').readAsBytesSync();
    expect(readId3v2Title(bytes), 'Tale One');
    expect(parseMp3(bytes).frameCount, lessThanOrEqualTo(parseMp3(File('${dir.path}/$f').readAsBytesSync()).frameCount - 100));
    expect(r.ownOutputs.single.name, 'Казка.mp3');
  });

  test('rename only → new name and title', () {
    applyEntrySync(dir, entry(name: 'Колобок'));
    expect(readId3v2Title(out('Колобок.mp3').readAsBytesSync()), 'Колобок');
  });

  test('split → part files with titles', () {
    final r = applyEntrySync(dir, entry(splits: const [150]));
    expect(r.status, EntryStatus.done);
    for (final n in ['Казка part 1', 'Казка part 2']) {
      expect(readId3v2Title(out('$n.mp3').readAsBytesSync()), n);
    }
  });

  test('conflict is per part', () {
    Directory('${dir.path}/cut').createSync();
    out('Казка part 2.mp3').writeAsStringSync('foreign');
    final r = applyEntrySync(dir, entry(splits: const [100, 200]));
    expect(r.results.map((x) => x.result), [OutputResult.written, OutputResult.conflict, OutputResult.written]);
    expect(out('Казка part 2.mp3').readAsStringSync(), 'foreign');
    expect(out('Казка part 1.mp3').existsSync(), isTrue);
    expect(out('Казка part 3.mp3').existsSync(), isTrue);
    expect(r.status, EntryStatus.conflict);
  });

  test('overwrite replaces only the named foreign files', () {
    Directory('${dir.path}/cut').createSync();
    out('Казка part 1.mp3').writeAsStringSync('foreign 1');
    out('Казка part 2.mp3').writeAsStringSync('foreign 2');
    final r = applyEntrySync(dir, entry(splits: const [150]), overwrite: {'Казка part 2.mp3'});
    expect(r.results.map((x) => x.result), [OutputResult.conflict, OutputResult.written]);
    expect(out('Казка part 1.mp3').readAsStringSync(), 'foreign 1');
    expect(readId3v2Title(out('Казка part 2.mp3').readAsBytesSync()), 'Казка part 2');
    expect(r.ownOutputs.map((o) => o.name), ['Казка part 2.mp3']);
  });

  test('own outputs are overwritten on re-apply', () {
    final first = applyEntrySync(dir, entry(deletes: const [FrameRange(10, 20)]));
    final again = applyEntrySync(dir, first.copyWith(deletes: const [FrameRange(10, 50)], status: EntryStatus.pending));
    expect(again.results.single.result, OutputResult.written);
    expect(again.status, EntryStatus.done);
  });

  test('own output changed by the user is a conflict', () {
    final first = applyEntrySync(dir, entry(deletes: const [FrameRange(10, 20)]));
    out('Казка.mp3').writeAsBytesSync([1], mode: FileMode.append);
    final again = applyEntrySync(dir, first.copyWith(status: EntryStatus.pending));
    expect(again.results.single.result, OutputResult.conflict);
    expect(again.ownOutputs, isEmpty);
  });

  test('obsolete own outputs are listed, not deleted', () {
    final first = applyEntrySync(dir, entry(splits: const [150]));
    final again = applyEntrySync(dir, first.copyWith(splits: const [], status: EntryStatus.pending));
    expect(again.obsolete, unorderedEquals(['Казка part 1.mp3', 'Казка part 2.mp3']));
    expect(out('Казка part 1.mp3').existsSync(), isTrue);
    expect(out('Казка.mp3').existsSync(), isTrue);
  });

  test('missing source → error', () {
    final e = entry();
    File('${dir.path}/$f').deleteSync();
    final r = applyEntrySync(dir, e.copyWith(deletes: const [FrameRange(1, 2)]));
    expect(r.status, EntryStatus.error);
    expect(r.results.single.result, OutputResult.error);
  });

  test('changed source → error', () {
    final e = entry(deletes: const [FrameRange(1, 2)]);
    File('${dir.path}/$f').setLastModifiedSync(DateTime(2001));
    expect(applyEntrySync(dir, e).status, EntryStatus.error);
  });

  test('no temp files left', () {
    applyEntrySync(dir, entry(splits: const [100, 200]));
    expect(Directory('${dir.path}/cut').listSync().where((e) => e.uri.pathSegments.last.startsWith('.')), isEmpty);
  });

  test('validateQueue finds bad and duplicate names', () {
    QueueEntry e(String file, {String? name, Map<int, String> parts = const {}, List<int> splits = const []}) =>
        QueueEntry(fileName: file, sourceSize: 1, sourceMtimeMs: 1, outputName: name, partNames: parts, splits: splits);
    final issues = validateQueue({
      'a.mp3': e('a.mp3', name: 'x/y'),
      'b.mp3': e('b.mp3', name: 'Ріпка'),
      'c.mp3': e('c.mp3', splits: const [10], parts: const {10: 'Ріпка'}),
      'd.mp3': e('d.mp3', name: 'Колобок'),
    });
    expect(issues['a.mp3'], [('x/y', NameProblem.slash)]);
    expect(issues['b.mp3'], [('Ріпка', NameProblem.duplicate)]);
    expect(issues['c.mp3'], [('Ріпка', NameProblem.duplicate)]);
    expect(issues.containsKey('d.mp3'), isFalse);
  });
}
