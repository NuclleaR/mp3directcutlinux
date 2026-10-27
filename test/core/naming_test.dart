import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/core/mp3/parts.dart';
import 'package:mp3_direct_cut/core/naming.dart';

import '../support/fixtures.dart';

void main() {
  final layout = syntheticLayout(100);
  List<PartPlan> parts(List<int> splits) => planParts(layout, const [], splits);

  test('defaults', () {
    expect(outputNames(sourceFileName: 'Казки 1.mp3', outputName: null, partNames: const {}, parts: parts([])),
        ['Казки 1']);
    expect(outputNames(sourceFileName: 'Казки 1.MP3', outputName: null, partNames: const {}, parts: parts([30, 60])),
        ['Казки 1 part 1', 'Казки 1 part 2', 'Казки 1 part 3']);
    expect(outputNames(sourceFileName: 'a.mp3', outputName: 'Збірка', partNames: const {}, parts: parts([50])),
        ['Збірка part 1', 'Збірка part 2']);
    expect(outputNames(sourceFileName: 'a.mp3', outputName: 'Збірка', partNames: const {}, parts: parts([])),
        ['Збірка']);
  });

  test('part names follow their split point', () {
    const names = {0: 'Колобок', 60: 'Ріпка'};
    expect(outputNames(sourceFileName: 'a.mp3', outputName: null, partNames: names, parts: parts([30, 60])),
        ['Колобок', 'a part 2', 'Ріпка']);
    expect(outputNames(sourceFileName: 'a.mp3', outputName: null, partNames: names, parts: parts([60])),
        ['Колобок', 'Ріпка']);
  });

  test('checkName', () {
    expect(checkName('  '), NameProblem.empty);
    expect(checkName('a/b'), NameProblem.slash);
    expect(checkName('a\u0000b'), NameProblem.slash);
    expect(checkName('я' * 130), NameProblem.tooLong);
    expect(checkName("Кіт і Лис — д'Артаньян"), isNull);
  });

  test('sourceBase strips .mp3 in any case', () {
    expect(sourceBase('Казка.Mp3'), 'Казка');
    expect(sourceBase('Казка.mp3.bak'), 'Казка.mp3.bak');
  });
}
