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
