import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/state/folder_controller.dart';

void main() {
  test('by numbers, chapters line up whatever the text before them', () {
    final names = [
      'Хроніки Вудсворда. Вперед в гру. Розділ 3.mp3',
      'Хроніки Вудсворда. Вперед, у гру. Розділ 1.mp3',
      'Хроніки Вудсворда. Вперед, у гру. Розділ 12.mp3',
      'Хроніки Вудсворда. Вперед, у гру. Розділ 14, 15.mp3',
      'Хроніки Вудсворта. Вперед у гру. Розділ 4..mp3',
      'Хроніки Вудсворта. Вперед, у гру. Розділ 2.mp3',
    ]..sort(compareByNumbers);
    expect(names.map((n) => RegExp(r'Розділ ([\d, ]+)').firstMatch(n)![1]), ['1', '2', '3', '4', '12', '14, 15']);
  });

  test('by numbers, every number counts in order and the .mp3 extension does not', () {
    final names = ['Книга 2 Розділ 1.mp3', 'Книга 1 Розділ 10.mp3', 'Книга 1 Розділ 9.mp3', 'Розділ 14.mp3', 'Розділ 14, 15.mp3']
      ..sort(compareByNumbers);
    expect(names, ['Книга 1 Розділ 9.mp3', 'Книга 1 Розділ 10.mp3', 'Книга 2 Розділ 1.mp3', 'Розділ 14.mp3', 'Розділ 14, 15.mp3']);
  });

  test('by numbers, equal numbers fall back to the name and huge numbers do not throw', () {
    final names = ['Ріпка 1.mp3', 'колобок 1.mp3', 'Без номера.mp3', 'Запис 123456789012345678901234567890.mp3', 'Запис 99.mp3']
      ..sort(compareByNumbers);
    expect(names, [
      'Без номера.mp3',
      'колобок 1.mp3',
      'Ріпка 1.mp3',
      'Запис 99.mp3',
      'Запис 123456789012345678901234567890.mp3',
    ]);
  });
}
