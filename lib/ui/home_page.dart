import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../state/folder_controller.dart';
import '../state/queue_controller.dart';
import '../state/selection_controller.dart';
import 'editor/editor_pane.dart';
import 'file_panel.dart';
import 'queue_bar.dart';
import 'theme/cut_palette.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Queue saves are debounced; write the last change before the window closes.
    _lifecycle = AppLifecycleListener(onExitRequested: () async {
      await ref.read(queueProvider.notifier).flush();
      return AppExitResponse.exit;
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = CutPalette.of(context);
    return Scaffold(
      body: Column(children: [
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(width: 300, child: FilePanel()),
            VerticalDivider(width: 1, color: palette.line),
            const Expanded(child: _EditorArea()),
          ]),
        ),
        Divider(height: 1, color: palette.line),
        const QueueBar(),
      ]),
    );
  }
}

class _EditorArea extends ConsumerWidget {
  const _EditorArea();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final selected = ref.watch(selectedFileProvider);
    final folder = ref.watch(folderProvider);
    if (selected != null && folder != null) {
      final path = '${folder.dir.path}/$selected';
      return EditorPane(key: ValueKey(path), fileName: selected, path: path);
    }
    final hasFolder = folder != null;
    return Center(
      child: Text(
        selected ?? (hasFolder ? l.pickFileHint : l.noFolder),
        style: TextStyle(color: CutPalette.of(context).muted),
      ),
    );
  }
}
