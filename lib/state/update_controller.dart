import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/update.dart';
import 'queue_controller.dart';
import 'settings_controller.dart';

/// Where this copy of the app runs from, and its version.
class AppInstall {
  const AppInstall({required this.version, required this.dir, required this.installed});

  /// The bundle at [dir]; [environment] decides where `install.sh` puts the app.
  factory AppInstall.at(Directory dir, [Map<String, String>? environment]) {
    var version = '?';
    try {
      final info = jsonDecode(File('${dir.path}/data/flutter_assets/version.json').readAsStringSync());
      version = (info as Map<String, dynamic>)['version'] as String;
    } catch (_) {
      // A test run or an odd bundle: the version stays unknown.
    }
    final env = environment ?? Platform.environment;
    final xdg = env['XDG_DATA_HOME'];
    final data = xdg != null && xdg.isNotEmpty ? xdg : '${env['HOME']}/.local/share';
    return AppInstall(version: version, dir: dir, installed: dir.path == '$data/mp3-direct-cut');
  }

  factory AppInstall.current() => AppInstall.at(File(Platform.resolvedExecutable).parent);

  final String version;
  final Directory dir;

  /// Put there by `install.sh`, so an update may replace [dir]. A build run from the
  /// source tree is never replaced.
  final bool installed;
}

final appInstallProvider = Provider<AppInstall>((ref) => AppInstall.current());

/// Finds, installs and starts new releases.
abstract interface class Updater {
  Future<Release?> newestRelease();
  Future<void> install(Release release, Directory appDir);

  /// Starts the app at [appDir] again and ends this process.
  Future<void> restart(Directory appDir);
}

/// Knows of no releases. The default, so tests never reach the network; `main` swaps in
/// [GitHubUpdater].
class NoUpdater implements Updater {
  const NoUpdater();

  @override
  Future<Release?> newestRelease() async => null;

  @override
  Future<void> install(Release release, Directory appDir) async => throw const UpdateException('updates are off');

  @override
  Future<void> restart(Directory appDir) async {}
}

class GitHubUpdater implements Updater {
  const GitHubUpdater();

  @override
  Future<Release?> newestRelease() => fetchNewestRelease();

  @override
  Future<void> install(Release release, Directory appDir) async {
    final tmp = await Directory.systemTemp.createTemp('mp3-direct-cut-');
    try {
      await installArchive(await downloadRelease(release, tmp), appDir);
    } finally {
      await tmp.delete(recursive: true);
    }
  }

  @override
  Future<void> restart(Directory appDir) async {
    await Process.start('${appDir.path}/mp3_direct_cut', const [], mode: ProcessStartMode.detached);
    exit(0);
  }
}

final updaterProvider = Provider<Updater>((ref) => const NoUpdater());

enum UpdateStage { idle, checking, upToDate, available, installing, installed, failed }

class UpdateState {
  const UpdateState({this.stage = UpdateStage.idle, this.release, this.error, this.bannerDismissed = false});

  final UpdateStage stage;

  /// The newer release once one is found.
  final Release? release;
  final String? error;

  /// The user said "later" to the banner; it stays hidden for this run.
  final bool bannerDismissed;

  bool get busy => stage == UpdateStage.checking || stage == UpdateStage.installing;

  UpdateState copyWith({UpdateStage? stage, Release? release, String? error, bool? bannerDismissed}) => UpdateState(
        stage: stage ?? this.stage,
        release: release ?? this.release,
        error: error,
        bannerDismissed: bannerDismissed ?? this.bannerDismissed,
      );
}

class UpdateController extends Notifier<UpdateState> {
  @override
  UpdateState build() => const UpdateState();

  /// Asks GitHub for a newer release. A [quiet] check, the one at startup, only ever
  /// changes anything when it finds one.
  Future<void> check({bool quiet = false}) async {
    if (state.busy) return;
    final before = state;
    if (!quiet) state = state.copyWith(stage: UpdateStage.checking);
    try {
      final newest = await ref.read(updaterProvider).newestRelease();
      final current = ref.read(appInstallProvider).version;
      if (newest != null && compareVersions(newest.version, current) > 0) {
        state = state.copyWith(stage: UpdateStage.available, release: newest);
      } else if (!quiet) {
        state = state.copyWith(stage: UpdateStage.upToDate);
      }
    } catch (e) {
      state = quiet ? before : state.copyWith(stage: UpdateStage.failed, error: '$e');
    }
  }

  /// Downloads the release found by [check] and puts it in place of the installed app.
  Future<void> install() async {
    final release = state.release, app = ref.read(appInstallProvider);
    if (state.stage != UpdateStage.available || release == null || !app.installed) return;
    state = state.copyWith(stage: UpdateStage.installing);
    try {
      await ref.read(updaterProvider).install(release, app.dir);
      state = state.copyWith(stage: UpdateStage.installed);
    } catch (e) {
      state = state.copyWith(stage: UpdateStage.failed, error: '$e');
    }
  }

  void dismissBanner() => state = state.copyWith(bannerDismissed: true);

  /// Saves what is pending and starts the new version.
  Future<void> restart() async {
    await ref.read(queueProvider.notifier).flush();
    await ref.read(settingsProvider.notifier).flush();
    await ref.read(updaterProvider).restart(ref.read(appInstallProvider).dir);
  }
}

final updateProvider = NotifierProvider<UpdateController, UpdateState>(UpdateController.new);
