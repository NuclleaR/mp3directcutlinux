import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/core/mp3/id3_title.dart';
import 'package:mp3_direct_cut/core/mp3/mp3_parser.dart';

import '../../support/fixtures.dart';
import '../../support/id3_reader.dart';

void main() {
  test('v2.3: title replaced, artist kept', () {
    final cbr = fixture('cbr_stereo_44k.mp3');
    final head = parseMp3(cbr).head;
    final r = id3v2WithTitle(head, 'Казка про Лисичку, ч. 2');
    expect(r.updated, isTrue);
    expect(r.bytes[3], 3);
    expect(readId3v2Title(r.bytes), 'Казка про Лисичку, ч. 2');
    expect(readId3v2Text(r.bytes, 'TPE1'), 'Test Artist');
    expect(readId3v2Frame(r.bytes, 'TIT2')![0], 1);
    expect(parseMp3(Uint8List.fromList([...r.bytes, ...cbr.sublist(head.length)])).frameCount, parseMp3(cbr).frameCount);
  });

  test('v2.4: UTF-8 encoding byte', () {
    final head = parseMp3(fixture('vbr_mono_22k.mp3')).head;
    final r = id3v2WithTitle(head, "Кіт і Лис — д'Артаньян");
    expect(r.updated, isTrue);
    expect(r.bytes[3], 4);
    expect(readId3v2Frame(r.bytes, 'TIT2')![0], 3);
    expect(readId3v2Title(r.bytes), "Кіт і Лис — д'Артаньян");
  });

  test('missing TIT2 is inserted', () {
    // v2.3 tag with only a TPE1 frame
    final tpe1 = [...ascii('TPE1'), 0, 0, 0, 3, 0, 0, 0, ...ascii('AB')];
    final head = Uint8List.fromList([...ascii('ID3'), 3, 0, 0, 0, 0, 0, tpe1.length, ...tpe1]);
    final r = id3v2WithTitle(head, 'Ріпка');
    expect(readId3v2Title(r.bytes), 'Ріпка');
    expect(readId3v2Text(r.bytes, 'TPE1'), 'AB');
  });

  test('no tag: creates a v2.3 tag', () {
    final r = id3v2WithTitle(Uint8List(0), 'Їжак');
    expect(r.updated, isTrue);
    expect(String.fromCharCodes(r.bytes.sublist(0, 3)), 'ID3');
    expect(r.bytes[3], 3);
    expect(readId3v2Title(r.bytes), 'Їжак');
  });

  test('v2.2 and unsynchronised tags untouched', () {
    final v22 = Uint8List.fromList([...ascii('ID3'), 2, 0, 0, 0, 0, 0, 10, ...Uint8List(10)]);
    final unsync = Uint8List.fromList([...ascii('ID3'), 3, 0, 0x80, 0, 0, 0, 10, ...Uint8List(10)]);
    for (final head in [v22, unsync]) {
      final r = id3v2WithTitle(head, 'X');
      expect(r.updated, isFalse);
      expect(r.bytes, head);
    }
  });

  test('ID3v1 Latin-1 title set, Cyrillic left alone', () {
    final tail = parseMp3(fixture('cbr_stereo_44k.mp3')).tail!;
    expect(readId3v1Title(id3v1WithTitle(tail, 'Fox Tale')!), 'Fox Tale');
    expect(readId3v1Title(id3v1WithTitle(tail, 'A' * 40)!), 'A' * 30);
    expect(id3v1WithTitle(tail, 'Казка'), tail);
    expect(id3v1WithTitle(null, 'X'), isNull);
  });
}

List<int> ascii(String s) => latin1.encode(s);
