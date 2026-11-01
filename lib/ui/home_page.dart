import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../state/folder_controller.dart';
import '../state/queue_controller.dart';
import '../state/selection_controller.dart';
import '../state/settings_controller.dart';
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
      await ref.read(settingsProvider.notifier).flush();
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
    final saved = ref.watch(settingsProvider.select((s) => s.panelWidth));
    return Scaffold(
      body: Column(children: [
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            // The file list keeps room for its toolbar and leaves the editor at least half.
            final maxWidth = math.max(_minPanelWidth, constraints.maxWidth / 2);
            final width = saved.clamp(_minPanelWidth, maxWidth);
            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(width: width, child: const FilePanel()),
              _PanelEdge(
                color: palette.line,
                // Several moves can arrive before the next build, so start from the stored width.
                onDrag: (dx) {
                  final current = ref.read(settingsProvider).panelWidth.clamp(_minPanelWidth, maxWidth);
                  ref.read(settingsProvider.notifier).setPanelWidth((current + dx).clamp(_minPanelWidth, maxWidth));
                },
              ),
              const Expanded(child: _EditorArea()),
            ]);
          }),
        ),
        Divider(height: 1, color: palette.line),
        const QueueBar(),
      ]),
    );
  }
}

const _minPanelWidth = 240.0;

/// The line between the file list and the editor; drag it to resize the list.
class _PanelEdge extends StatelessWidget {
  const _PanelEdge({required this.color, required this.onDrag});

  final Color color;
  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) => MouseRegion(
        key: const Key('panelEdge'),
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Counts the movement from the press, so the edge stays under the pointer.
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
          // Wider than the line it draws, so it is easy to grab.
          child: SizedBox(width: 5, child: Center(child: VerticalDivider(width: 1, color: color))),
        ),
      );
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
