import 'dart:async';

import 'package:mp3_direct_cut/audio/audio_engine.dart';

/// Records what the app asks of the player; tests move [position] by hand.
class FakeAudioEngine implements AudioEngine {
  @override
  double position = 0;
  @override
  bool playing = false;
  String? opened;
  final seeks = <double>[];
  final _playing = StreamController<bool>.broadcast();

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Future<void> open(String path) async => opened = path;

  @override
  Future<void> play() async {
    playing = true;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    playing = false;
    _playing.add(false);
  }

  @override
  Future<void> seek(double seconds) async {
    seeks.add(seconds);
    position = seconds;
  }

  @override
  Future<void> dispose() => _playing.close();
}
