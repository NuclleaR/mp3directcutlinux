import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../state/apply_controller.dart';
import '../state/folder_controller.dart';
import '../state/queue_controller.dart';
import '../state/queue_entry.dart';
import '../state/selection_controller.dart';
import 'theme/cut_palette.dart';

class FilePanel extends ConsumerWidget {
  const FilePanel({super.key});

  Future<void> _open(WidgetRef ref) async {
    final path = await ref.read(folderPickerProvider)();
    if (path != null) await ref.read(folderProvider.notifier).open(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final palette = CutPalette.of(context);
    final folder = ref.watch(folderProvider);
    // Apply writes its results into the open folder's queue, so the folder stays put meanwhile.
    final applying = ref.watch(applyProvider.select((a) => a.running));
    return Material(
      color: palette.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: applying ? null : () => _open(ref),
              icon: const Icon(Icons.folder_open),
              label: Text(l.openFolder),
            ),
          ),
          if (folder != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(folder.dir.path, style: TextStyle(color: palette.muted, fontSize: 12)),
            ),
          const Divider(height: 1),
          Expanded(
            child: folder == null
                ? _Hint(l.noFolder)
                : folder.files.isEmpty
                    ? _Hint(l.noMp3InFolder)
                    : ListView.builder(
                        itemCount: folder.files.length,
                        itemBuilder: (context, i) => _FileRow(
                          name: folder.files[i].name,
                          path: '${folder.dir.path}/${folder.files[i].name}',
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: TextStyle(color: CutPalette.of(context).muted)),
      );
}

class _FileRow extends ConsumerWidget {
  const _FileRow({required this.name, required this.path});

  final String name;
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final palette = CutPalette.of(context);
    final isMp3 = ref.watch(probeProvider(path)).value ?? true;
    final queue = ref.watch(queueProvider);
    final entry = queue.entries[name];
    final stale = queue.isStale(name);
    final selected = ref.watch(selectedFileProvider) == name;

    Widget count(IconData icon, int n) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: palette.muted),
          const SizedBox(width: 2),
          Text('$n'),
          const SizedBox(width: 8),
        ]);

    final status = switch (entry?.status) {
      EntryStatus.done => (l.statusDone, palette.sel),
      EntryStatus.conflict => (l.statusConflict, palette.playhead),
      EntryStatus.error => (l.statusError, palette.cut),
      _ => null,
    };

    final tile = ListTile(
      dense: true,
      enabled: isMp3,
      selected: selected,
      title: Text(name),
      subtitle: entry == null
          ? null
          : Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (entry.deletes.isNotEmpty) count(Icons.content_cut, entry.deletes.length),
              if (entry.splits.isNotEmpty) count(Icons.call_split, entry.splits.length),
              if (entry.outputName != null || entry.partNames.isNotEmpty)
                Icon(Icons.drive_file_rename_outline, size: 14, color: palette.muted),
              if (stale) Text(l.statusStale, style: TextStyle(color: palette.playhead, fontSize: 12)),
            ]),
      trailing: stale
          ? IconButton(
              tooltip: l.clearStale,
              icon: const Icon(Icons.check, size: 18),
              onPressed: () => ref.read(queueProvider.notifier).clearStale(name),
            )
          : status == null
              ? null
              : Text(status.$1, style: TextStyle(color: status.$2, fontSize: 12)),
      onTap: isMp3 ? () => ref.read(selectedFileProvider.notifier).select(name) : null,
    );
    return isMp3 ? tile : Tooltip(message: l.notMp3, child: tile);
  }
}
