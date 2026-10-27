import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'native_audio_engine.dart';

/// The bits of an audio player the editor needs; positions are in seconds.
abstract class AudioEngine {
  Future<void> open(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(double seconds);
  double get position;
  bool get playing;
  Stream<bool> get playingStream;
  Future<void> dispose();
}

final audioEngineProvider = Provider<AudioEngine>((ref) {
  final engine = NativeAudioEngine();
  ref.onDispose(engine.dispose);
  return engine;
});
