import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'queue_entry.dart';

class QueueLoad {
  const QueueLoad(this.entries, this.brokenBackupName);

  final Map<String, QueueEntry> entries;

  /// Set when the queue file could not be read and was moved aside under this name.
  final String? brokenBackupName;
}

/// Reads and writes the work queue as JSON in the opened folder.
class QueueStore {
  static const fileName = '.mp3directcut-queue.json';

  Future<QueueLoad> load(Directory folder) async {
    final file = File('${folder.path}/$fileName');
    if (!await file.exists()) return const QueueLoad({}, null);
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic> || json['version'] != 1) throw const FormatException('unknown queue format');
      final entries = json['entries'] as Map<String, dynamic>;
      return QueueLoad({
        for (final e in entries.entries) e.key: QueueEntry.fromJson(e.key, e.value as Map<String, dynamic>),
      }, null);
    } catch (_) {
      // Never overwrite a queue we cannot read: keep it aside and start empty.
      final backup = '.mp3directcut-queue.broken-${_stamp(DateTime.now())}.json';
      await file.rename('${folder.path}/$backup');
      return QueueLoad({}, backup);
    }
  }

  Future<void> save(Directory folder, Map<String, QueueEntry> entries) async {
    final tmp = File('${folder.path}/$fileName.tmp');
    final json = {
      'version': 1,
      'entries': {for (final e in entries.entries) e.key: e.value.toJson()},
    };
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(json), flush: true);
    await tmp.rename('${folder.path}/$fileName');
  }

  static String _stamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }
}

final queueStoreProvider = Provider<QueueStore>((ref) => QueueStore());
