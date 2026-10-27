import 'dart:async';

import 'package:media_kit/media_kit.dart';

import 'audio_engine.dart';

/// [AudioEngine] on top of media_kit (libmpv).
class MediaKitEngine implements AudioEngine {
  MediaKitEngine() : _player = Player() {
    final platform = _player.platform;
    // Exact seeks, so skipping a delete range lands on its end and not on a nearby keyframe.
    if (platform is NativePlayer) unawaited(platform.setProperty('hr-seek', 'yes'));
  }

  final Player _player;

  @override
  Future<void> open(String path) => _player.open(Media(path), play: false);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(double seconds) => _player.seek(Duration(microseconds: (seconds * 1e6).round()));

  @override
  double get position => _player.state.position.inMicroseconds / 1e6;

  @override
  bool get playing => _player.state.playing;

  @override
  Stream<bool> get playingStream => _player.stream.playing;

  @override
  Future<void> dispose() => _player.dispose();
}
