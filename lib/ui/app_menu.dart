import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/update.dart';
import '../l10n/app_localizations.dart';
import '../state/apply_controller.dart';
import '../state/update_controller.dart';
import 'theme/cut_palette.dart';

/// The ☰ menu in the window's title bar. The GTK runner draws it; Dart gives it its
/// items and hears which one was chosen.
abstract final class AppMenu {
  static const _channel = MethodChannel('mp3_direct_cut/menu');
  static const about = 'about';
  static const checkUpdates = 'check-updates';

  static Future<void> setItems(AppLocalizations l) async {
    try {
      await _channel.invokeMethod<void>('setItems', [
        [about, l.menuAbout],
        [checkUpdates, l.menuCheckUpdates],
      ]);
    } on MissingPluginException {
      // No runner menu, as in widget tests.
    }
  }

  static void onSelect(void Function(String id)? handler) => _channel.setMethodCallHandler(handler == null
      ? null
      : (call) async {
          if (call.method == 'select') handler(call.arguments as String);
        });
}

Future<void> openUrl(Uri url) =>
    Process.run('xdg-open', [url.toString()]).then((_) {}, onError: (Object _) {});

void showAbout(BuildContext context, AppInstall app) {
  final l = AppLocalizations.of(context);
  showAboutDialog(
    context: context,
    applicationName: 'MP3 Direct Cut',
    applicationVersion: app.version,
    applicationIcon: Image.file(
      File('${app.dir.path}/data/app_icon.png'),
      width: 48,
      height: 48,
      errorBuilder: (_, _, _) => const Icon(Icons.content_cut, size: 48),
    ),
    children: [
      Text(l.aboutDescription),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => openUrl(repoPage),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text(l.aboutSource),
        ),
      ),
    ],
  );
}

/// Checks for updates when [check] is set, then follows the update to its end.
Future<void> showUpdateDialog(BuildContext context, WidgetRef ref, {bool check = false}) {
  if (check) ref.read(updateProvider.notifier).check();
  return showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const UpdateDialog());
}

class UpdateDialog extends ConsumerWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final update = ref.watch(updateProvider);
    final app = ref.watch(appInstallProvider);
    final applying = ref.watch(applyProvider.select((a) => a.running));
    final release = update.release;
    final notifier = ref.read(updateProvider.notifier);
    void close() => Navigator.pop(context);

    Widget progress(String text) => Row(children: [
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 16),
          Expanded(child: Text(text)),
        ]);

    final (Widget body, List<Widget> actions) = switch (update.stage) {
      UpdateStage.idle || UpdateStage.checking => (progress(l.updateChecking), const <Widget>[]),
      UpdateStage.upToDate => (Text(l.updateUpToDate(app.version)), [FilledButton(onPressed: close, child: Text(l.close))]),
      UpdateStage.failed => (Text(l.updateFailed(update.error ?? '')), [FilledButton(onPressed: close, child: Text(l.close))]),
      UpdateStage.available when app.installed => (
          Text(l.updateAvailable(release!.version, app.version)),
          [
            TextButton(onPressed: close, child: Text(l.later)),
            FilledButton(onPressed: notifier.install, child: Text(l.updateNow)),
          ],
        ),
      UpdateStage.available => (
          Text('${l.updateAvailable(release!.version, app.version)}\n\n${l.updateNotInstalled}'),
          [
            TextButton(onPressed: close, child: Text(l.close)),
            FilledButton(onPressed: () => openUrl(release.pageUrl), child: Text(l.openReleasePage)),
          ],
        ),
      UpdateStage.installing => (progress(l.updateInstalling(release!.version)), const <Widget>[]),
      UpdateStage.installed => (
          Text(l.updateInstalled(release!.version)),
          [
            TextButton(onPressed: close, child: Text(l.later)),
            // A restart in the middle of Apply would cut a file short.
            FilledButton(onPressed: applying ? null : notifier.restart, child: Text(l.restart)),
          ],
        ),
    };
    return AlertDialog(
      title: Text(l.updateTitle),
      content: SizedBox(width: 420, child: body),
      actions: actions,
    );
  }
}

/// A slim line at the top of the window when the startup check found a newer release.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final palette = CutPalette.of(context);
    final update = ref.watch(updateProvider);
    final release = update.release;
    if (update.stage != UpdateStage.available || update.bannerDismissed || release == null) {
      return const SizedBox.shrink();
    }
    return Material(
      color: palette.panel,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          Icon(Icons.system_update_alt, size: 18, color: palette.muted),
          const SizedBox(width: 8),
          Expanded(child: Text(l.updateBanner(release.version), overflow: TextOverflow.ellipsis)),
          TextButton(onPressed: ref.read(updateProvider.notifier).dismissBanner, child: Text(l.later)),
          const SizedBox(width: 8),
          FilledButton(onPressed: () => showUpdateDialog(context, ref), child: Text(l.updateNow)),
        ]),
      ),
    );
  }
}
