import 'dart:io';

/// Builds native/mp3_analyze.c into a shared library for host tests and returns its path.
String buildNativeLib() {
  const dir = '.dart_tool/test_native';
  const out = '$dir/libmp3_analyze.so';
  Directory(dir).createSync(recursive: true);
  final r = Process.runSync('cc', [
    '-shared', '-fPIC', '-O2', //
    '-Inative/third_party/minimp3',
    '-o', out, 'native/mp3_analyze.c', '-lm',
  ]);
  if (r.exitCode != 0) throw StateError('cc failed: ${r.stderr}');
  return File(out).absolute.path;
}

/// Builds native/mp3_player.c into a shared library for host tests and returns its path.
/// miniaudio is large, so the library is rebuilt only when the source is newer.
String buildPlayerLib() {
  const dir = '.dart_tool/test_native';
  const out = '$dir/libmp3_player.so';
  const src = 'native/mp3_player.c';
  Directory(dir).createSync(recursive: true);
  final lib = File(out);
  if (lib.existsSync() && lib.lastModifiedSync().isAfter(File(src).lastModifiedSync())) return lib.absolute.path;
  final r = Process.runSync('cc', [
    '-shared', '-fPIC', '-O2', '-fvisibility=hidden', //
    '-Inative/third_party/minimp3', '-Inative/third_party/miniaudio',
    '-o', out, src, '-lm', '-lpthread', '-ldl',
  ]);
  if (r.exitCode != 0) throw StateError('cc failed: ${r.stderr}');
  return lib.absolute.path;
}
