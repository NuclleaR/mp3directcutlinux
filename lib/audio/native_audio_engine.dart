import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'audio_engine.dart';

typedef _CreateNative = Pointer<Void> Function(Int32 silent);
typedef _CreateDart = Pointer<Void> Function(int silent);
typedef _OpenNative = Int32 Function(Pointer<Void> player, Pointer<Utf8> path);
typedef _OpenDart = int Function(Pointer<Void> player, Pointer<Utf8> path);
typedef _SetPlayingNative = Void Function(Pointer<Void> player, Int32 playing);
typedef _SetPlayingDart = void Function(Pointer<Void> player, int playing);
typedef _IsPlayingNative = Int32 Function(Pointer<Void> player);
typedef _IsPlayingDart = int Function(Pointer<Void> player);
typedef _SeekNative = Void Function(Pointer<Void> player, Double seconds);
typedef _SeekDart = void Function(Pointer<Void> player, double seconds);
typedef _PositionNative = Double Function(Pointer<Void> player);
typedef _PositionDart = double Function(Pointer<Void> player);
typedef _DestroyNative = Void Function(Pointer<Void> player);
typedef _DestroyDart = void Function(Pointer<Void> player);

/// The player library inside the installed bundle, next to the executable.
String defaultPlayerLibraryPath() => '${File(Platform.resolvedExecutable).parent.path}/lib/libmp3_player.so';

/// [AudioEngine] on the bundled native player (native/mp3_player.c: miniaudio and minimp3),
/// so playback needs nothing beyond the desktop's own sound system.
class NativeAudioEngine implements AudioEngine {
  /// [silent] plays through a null device that keeps real time without a sound card.
  NativeAudioEngine({String? libraryPath, bool silent = false}) {
    final lib = DynamicLibrary.open(libraryPath ?? defaultPlayerLibraryPath());
    _open = lib.lookupFunction<_OpenNative, _OpenDart>('mp3_player_open');
    _setPlaying = lib.lookupFunction<_SetPlayingNative, _SetPlayingDart>('mp3_player_set_playing');
    _isPlaying = lib.lookupFunction<_IsPlayingNative, _IsPlayingDart>('mp3_player_is_playing');
    _seek = lib.lookupFunction<_SeekNative, _SeekDart>('mp3_player_seek');
    _position = lib.lookupFunction<_PositionNative, _PositionDart>('mp3_player_position');
    _destroy = lib.lookupFunction<_DestroyNative, _DestroyDart>('mp3_player_destroy');
    _player = lib.lookupFunction<_CreateNative, _CreateDart>('mp3_player_create')(silent ? 1 : 0);
  }

  late final _OpenDart _open;
  late final _SetPlayingDart _setPlaying;
  late final _IsPlayingDart _isPlaying;
  late final _SeekDart _seek;
  late final _PositionDart _position;
  late final _DestroyDart _destroy;
  late Pointer<Void> _player;

  final _playingChanges = StreamController<bool>.broadcast();

  /// Runs while playing, to notice the end of the file.
  Timer? _watch;

  bool get _ready => _player != nullptr;

  @override
  Future<void> open(String path) async {
    if (!_ready) throw const FileSystemException('No sound output is available');
    _stopped();
    final p = path.toNativeUtf8();
    try {
      if (_open(_player, p) != 0) throw FileSystemException('Cannot play this file', path);
    } finally {
      malloc.free(p);
    }
  }

  @override
  Future<void> play() async {
    if (!_ready || playing) return;
    _setPlaying(_player, 1);
    if (!playing) return;
    _playingChanges.add(true);
    _watch = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!playing) _stopped();
    });
  }

  @override
  Future<void> pause() async {
    if (!_ready) return;
    _setPlaying(_player, 0);
    _stopped();
  }

  void _stopped() {
    if (_watch == null) return;
    _watch!.cancel();
    _watch = null;
    _playingChanges.add(false);
  }

  @override
  Future<void> seek(double seconds) async {
    if (_ready) _seek(_player, seconds);
  }

  @override
  double get position => _ready ? _position(_player) : 0;

  @override
  bool get playing => _ready && _isPlaying(_player) != 0;

  @override
  Stream<bool> get playingStream => _playingChanges.stream;

  @override
  Future<void> dispose() async {
    _watch?.cancel();
    _watch = null;
    if (_ready) {
      _destroy(_player);
      _player = nullptr;
    }
    await _playingChanges.close();
  }
}
