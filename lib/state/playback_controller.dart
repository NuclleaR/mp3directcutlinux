import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_engine.dart';
import '../core/frame_range.dart';
import '../ui/editor/view_window.dart';
import 'editor_controller.dart';
import 'queue_controller.dart';

/// The end of the skip range that [t] is in (or just before), if any.
double? skipTarget(double t, List<(double, double)> skips) {
  for (final (a, b) in skips) {
    if (t >= a - 0.01 && t < b) return b;
  }
  return null;
}

class PlaybackState {
  const PlaybackState({this.playing = false});

  final bool playing;
}

class PlaybackController extends Notifier<PlaybackState> {
  double? _stopAt;
  (double, double)? _tempSkip;
  String? _openPath;

  AudioEngine get _engine => ref.read(audioEngineProvider);

  @override
  PlaybackState build() {
    final sub = ref.watch(audioEngineProvider).playingStream.listen((p) => state = PlaybackState(playing: p));
    ref.onDispose(sub.cancel);
    return const PlaybackState();
  }

  double get position => _engine.position;

  /// Pauses and loads [path] unless it is already loaded.
  Future<void> openFile(String path) async {
    if (_openPath == path) return;
    _openPath = path;
    _stopAt = null;
    _tempSkip = null;
    await _engine.pause();
    await _engine.open(path);
  }

  Future<void> togglePlay() async {
    if (_engine.playing) {
      await _engine.pause();
    } else {
      _stopAt = null;
      _tempSkip = null;
      await _engine.play();
    }
  }

  Future<void> seek(double t) => _engine.seek(t);

  /// Plays two seconds either side of `[a, b]`, jumping over it, then stops.
  Future<void> listenJoin(double a, double b) async {
    _stopAt = b + 2;
    _tempSkip = (a, b);
    await _engine.seek(max(0, a - 2));
    await _engine.play();
  }

  /// Called every frame while the editor is visible.
  void tick() {
    if (!_engine.playing) return;
    final t = _engine.position;
    final editor = ref.read(editorProvider);
    final fd = editor.frameDuration;
    final entry = ref.read(queueProvider).entries[editor.fileName];
    final skips = <(double, double)>[
      for (final r in entry?.deletes ?? const <FrameRange>[]) (r.start * fd, r.end * fd),
      ?_tempSkip,
    ];
    final target = skipTarget(t, skips);
    if (target != null) unawaited(_engine.seek(target));
    if (_stopAt != null && t >= _stopAt!) {
      _stopAt = null;
      _tempSkip = null;
      unawaited(_engine.pause());
      return;
    }
    final v = editor.view;
    if (t > v.start + v.span * 0.95 || t < v.start) {
      ref.read(editorProvider.notifier).setView(ViewWindow(t - v.span * 0.1, v.span));
    }
  }
}

final playbackProvider = NotifierProvider<PlaybackController, PlaybackState>(PlaybackController.new);
