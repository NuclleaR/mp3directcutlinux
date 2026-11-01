import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/state/folder_controller.dart';

void main() {
  test('by date, the newest file comes first and equal times fall back to the name', () {
    Mp3FileInfo f(String name, int mtimeMs) => Mp3FileInfo(name: name, size: 1, mtimeMs: mtimeMs);
    final files = [f('Розділ 1.mp3', 100), f('Розділ 3.mp3', 300), f('Розділ 10.mp3', 200), f('Розділ 2.mp3', 200)]
      ..sort(compareByDate);
    expect(files.map((e) => e.name), ['Розділ 3.mp3', 'Розділ 2.mp3', 'Розділ 10.mp3', 'Розділ 1.mp3']);
  });
}
