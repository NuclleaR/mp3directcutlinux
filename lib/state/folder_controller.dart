import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'queue_controller.dart';

class Mp3FileInfo {
  const Mp3FileInfo({required this.name, required this.size, required this.mtimeMs});

  final String name;
  final int size;
  final int mtimeMs;
}

class FolderState {
  const FolderState({required this.dir, required this.files});

  final Directory dir;
  final List<Mp3FileInfo> files;
}

class FolderController extends Notifier<FolderState?> {
  @override
  FolderState? build() => null;

  /// Lists the top-level `*.mp3` files of [path] and loads its queue.
  Future<void> open(String path) async {
    final dir = Directory(path);
    final files = await _list(dir);
    state = FolderState(dir: dir, files: files);
    await ref.read(queueProvider.notifier).load(dir, files);
  }

  Future<void> refresh() async {
    final current = state;
    if (current == null) return;
    final files = await _list(current.dir);
    state = FolderState(dir: current.dir, files: files);
    ref.read(queueProvider.notifier).updateSources(files);
  }

  Future<List<Mp3FileInfo>> _list(Directory dir) async {
    final files = <Mp3FileInfo>[];
    await for (final e in dir.list(followLinks: false)) {
      if (e is! File) continue;
      final name = e.uri.pathSegments.last;
      if (!name.toLowerCase().endsWith('.mp3')) continue;
      final stat = await e.stat();
      files.add(Mp3FileInfo(name: name, size: stat.size, mtimeMs: stat.modified.millisecondsSinceEpoch));
    }
    files.sort((a, b) => naturalCompare(a.name, b.name));
    return files;
  }
}

final _chunk = RegExp(r'\d+|\D+');

/// Case-insensitive order in which "Казка 2" comes before "Казка 10".
int naturalCompare(String a, String b) {
  final x = _chunk.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
  final y = _chunk.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
  for (var i = 0; i < x.length && i < y.length; i++) {
    final nx = int.tryParse(x[i]), ny = int.tryParse(y[i]);
    final c = nx != null && ny != null ? nx.compareTo(ny) : x[i].compareTo(y[i]);
    if (c != 0) return c;
  }
  return x.length.compareTo(y.length);
}

final _digits = RegExp(r'\d+');
final _extension = RegExp(r'\.[^.]*$');

/// Order by the numbers in the file names alone, ignoring the extension: "Глава 3" and
/// "Глава, 10" sort by 3 and 10 whatever the text around them. Equal numbers fall back to
/// [naturalCompare].
int compareByNumbers(String a, String b) {
  List<String> numbers(String s) => [for (final m in _digits.allMatches(s.replaceFirst(_extension, ''))) m[0]!];
  final x = numbers(a), y = numbers(b);
  for (var i = 0; i < x.length && i < y.length; i++) {
    final c = _compareDigits(x[i], y[i]);
    if (c != 0) return c;
  }
  final c = x.length.compareTo(y.length);
  return c != 0 ? c : naturalCompare(a, b);
}

/// Compares two runs of digits by value, however long they are.
int _compareDigits(String a, String b) {
  final x = a.replaceFirst(RegExp(r'^0+(?=\d)'), ''), y = b.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  return x.length != y.length ? x.length.compareTo(y.length) : x.compareTo(y);
}

final folderProvider = NotifierProvider<FolderController, FolderState?>(FolderController.new);

final folderPickerProvider = Provider<Future<String?> Function()>((ref) => getDirectoryPath);
