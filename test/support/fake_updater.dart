import 'dart:io';

import 'package:mp3_direct_cut/core/update.dart';
import 'package:mp3_direct_cut/state/update_controller.dart';

class FakeUpdater implements Updater {
  FakeUpdater({this.newest, this.error, this.installError});

  final Release? newest;
  final Object? error;
  final Object? installError;

  /// (version, app dir) of every install.
  final installed = <(String, String)>[];
  int restarts = 0;

  @override
  Future<Release?> newestRelease() async {
    if (error != null) throw error!;
    return newest;
  }

  @override
  Future<void> install(Release release, Directory appDir) async {
    if (installError != null) throw installError!;
    installed.add((release.version, appDir.path));
  }

  @override
  Future<void> restart(Directory appDir) async => restarts++;
}
