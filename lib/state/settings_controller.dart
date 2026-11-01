import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How the file list is ordered: by name, or newest modification time first.
enum FileSort { name, date }

/// App-wide preferences; nothing here is stored in the open folder.
@immutable
class AppSettings {
  const AppSettings({this.fileSort = FileSort.name, this.panelWidth = 300});

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        fileSort: FileSort.values.asNameMap()[j['fileSort']] ?? FileSort.name,
        panelWidth: (j['panelWidth'] as num?)?.toDouble() ?? 300,
      );

  final FileSort fileSort;

  /// Width of the file list in logical pixels.
  final double panelWidth;

  AppSettings copyWith({FileSort? fileSort, double? panelWidth}) =>
      AppSettings(fileSort: fileSort ?? this.fileSort, panelWidth: panelWidth ?? this.panelWidth);

  Map<String, Object?> toJson() => {'fileSort': fileSort.name, 'panelWidth': panelWidth};
}

abstract interface class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

/// Keeps settings for this run only. The default store, so tests never touch the user's
/// config; `main` swaps in [FileSettingsStore].
class MemorySettingsStore implements SettingsStore {
  AppSettings _saved = const AppSettings();

  @override
  Future<AppSettings> load() async => _saved;

  @override
  Future<void> save(AppSettings settings) async => _saved = settings;
}

/// Settings in `$XDG_CONFIG_HOME/mp3-direct-cut/settings.json`, or `~/.config/...`.
class FileSettingsStore implements SettingsStore {
  FileSettingsStore(this.file);

  factory FileSettingsStore.forUser([Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;
    final xdg = env['XDG_CONFIG_HOME'];
    final base = xdg != null && xdg.isNotEmpty ? xdg : '${env['HOME']}/.config';
    return FileSettingsStore(File('$base/mp3-direct-cut/settings.json'));
  }

  final File file;

  /// A missing or unreadable file gives the defaults.
  @override
  Future<AppSettings> load() async {
    try {
      return AppSettings.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(settings.toJson()), flush: true);
    await tmp.rename(file.path);
  }
}

final settingsStoreProvider = Provider<SettingsStore>((ref) => MemorySettingsStore());

class SettingsController extends Notifier<AppSettings> {
  Timer? _saveTimer;
  bool _changed = false;

  @override
  AppSettings build() {
    ref.onDispose(() => _saveTimer?.cancel());
    ref.read(settingsStoreProvider).load().then((saved) {
      // A change made before the file was read wins over the file.
      if (ref.mounted && !_changed) state = saved;
    });
    return const AppSettings();
  }

  void setFileSort(FileSort sort) => _set(state.copyWith(fileSort: sort));

  void setPanelWidth(double width) => _set(state.copyWith(panelWidth: width));

  /// Writes a pending change now.
  Future<void> flush() {
    if (_saveTimer == null) return Future.value();
    _saveTimer!.cancel();
    _saveTimer = null;
    return _save();
  }

  void _set(AppSettings next) {
    _changed = true;
    state = next;
    _saveTimer?.cancel();
    // Dragging the panel edge changes the width on every frame; write once it settles.
    _saveTimer = Timer(const Duration(milliseconds: 300), () {
      _saveTimer = null;
      _save();
    });
  }

  /// Preferences only: a failed write keeps them for this run and is not worth an error.
  Future<void> _save() => ref.read(settingsStoreProvider).save(state).catchError((Object _) {});
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
