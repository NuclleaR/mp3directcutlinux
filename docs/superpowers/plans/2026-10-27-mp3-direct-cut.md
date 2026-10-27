# MP3 Direct Cut Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A native Linux Flutter app that marks delete ranges, split points and output names on many MP3s in one folder, then losslessly writes all results into `cut/` with one Apply.

**Architecture:** A pure-Dart MP3 core (port of the artifact's `CORE` block plus splitting and ID3 title rewrite) does all cutting. A small C library built from vendored minimp3 decodes audio only for the waveform and silence detection, called via `dart:ffi` in a background isolate. Riverpod notifiers hold the folder, the persisted work queue, the editor state, playback (media_kit) and Apply.

**Tech Stack:** Flutter 3.47.8 / Dart 3.13 (via `mise`), Linux desktop, `flutter_riverpod` 3 (no codegen), `media_kit` + `media_kit_libs_audio`, `file_selector`, `ffi`, `flutter_localizations` + `intl` (gen-l10n), minimp3 (CC0, vendored C).

**Spec:** [docs/superpowers/specs/2026-10-27-mp3-direct-cut-design.md](../specs/2026-10-27-mp3-direct-cut-design.md). Reference implementation of every ported behaviour: [docs/reference/mp3-nozhytsi-artifact.html](../../reference/mp3-nozhytsi-artifact.html) (the `CORE-START`…`CORE-END` block and the UI script below it).

## Global Constraints

- **Do not commit.** Leave all changes in the working tree; the user decides when to commit. Never add AI attribution anywhere.
- Shell: run commands from the project root, never `cd` into it; use paths relative to the project root. `flutter`/`dart` are not on PATH in non-interactive shells: run them as `mise exec -- flutter …`.
- Linux only: the project is created with `--platforms linux`; no other platform folders.
- Package `mp3_direct_cut`, org `com.example`, application id `com.example.mp3_direct_cut`, window title `MP3 Direct Cut`.
- Allowed direct dependencies: `flutter_riverpod`, `media_kit`, `media_kit_libs_audio`, `file_selector`, `ffi`, `flutter_localizations` (sdk), `intl`. Dev: `flutter_test`, `flutter_lints` (template defaults). Nothing else — not `path`, not `google_fonts`, not `desktop_drop`. Fonts are the system fonts (artifact's IBM Plex is not ported).
- Originals are never written, renamed, moved or deleted. All output goes to `<folder>/cut/`.
- No re-encoding: output audio frames are byte copies of source frames.
- Only top-level `*.mp3` files of the opened folder (case-insensitive extension); no subfolders.
- Queue file: `<folder>/.mp3directcut-queue.json`. Output folder: `<folder>/cut/`.
- Default names: no split → `<original base>.mp3`; split → `<base> part N.mp3` (N from 1, space before `part`, no zero padding). `<base>` is the file-level output name if set, else the original name without `.mp3`.
- Interface strings come only from ARB files (`lib/l10n/app_en.arb`, `lib/l10n/app_uk.arb`); system locale chooses; anything other than `uk` falls back to `en`.
- Keyboard shortcuts match on `PhysicalKeyboardKey` so they work on the Ukrainian layout.
- Positions in the model are **frame indices** (int); seconds exist only in the UI (`seconds = frame * frameDuration`).

## Review Focus

1. A `.mp3` in the folder that is empty, truncated or not MP3 at all → its row shows "not an MP3", it cannot be marked, other files work (Task 2 parser test, Task 7 widget test).
2. 1-hour+ files (~60 MB, ~140 000 frames) → opening stays responsive (analysis in an isolate), Apply works (Task 4 isolate test, Task 2 synthetic long-file parse test).
3. The queue JSON is damaged or hand-edited → the app never crashes and never overwrites it silently: it keeps a backup copy, starts an empty queue and tells the user (Task 5 test).
4. Ukrainian names with spaces, apostrophes and long titles → correct file names in `cut/`, correct UTF-16/UTF-8 ID3 titles, names over 255 bytes rejected before Apply (Task 3 tests).
5. A source file deleted or changed between marking and Apply, or the app killed mid-Apply → that entry reports an error/stale, other entries still run, no truncated `cut/*.mp3` is ever left (Task 6 tests).

---

### Task 1: Project scaffold, localisation, theme

**Files:**
- Create (generator): Flutter project in the repository root.
- Modify: `linux/runner/my_application.cc` (both title strings → `MP3 Direct Cut`)
- Modify: `pubspec.yaml` (`flutter: generate: true`, dependencies)
- Create: `l10n.yaml`, `lib/l10n/app_en.arb`, `lib/l10n/app_uk.arb`
- Create: `lib/main.dart`, `lib/app.dart`, `lib/ui/theme/cut_palette.dart`
- Create: `.gitignore` additions: `.dart_tool/`, `build/` (template provides them; keep)
- Test: `test/app_smoke_test.dart`

**Interfaces:**
- Produces: `class App extends StatelessWidget` (MaterialApp with `AppLocalizations.localizationsDelegates`, `supportedLocales: [Locale('en'), Locale('uk')]`, light/dark themes, `home: HomePage()` — `HomePage` is a placeholder `Scaffold` until Task 7).
- Produces: `class CutPalette extends ThemeExtension<CutPalette>` with `Color` fields `bg, panel, line, fg, muted, wave, waveBg, sel, selFill, cut, cutFill, playhead, split, btn, btnHover, primary, primaryFg`; `static const light`, `static const dark`. Values copied from the artifact's `:root` and dark blocks; `split` is new: light `#7A4FC4`, dark `#A98AE8`.
- Produces: `AppLocalizations` (generated) with the keys in the table below.

- [ ] **Step 1: Generate the project**

Run: `mise exec -- flutter create --platforms linux --org com.example --project-name mp3_direct_cut --empty .`
Expected: `All done!`; `linux/`, `lib/main.dart`, `pubspec.yaml` exist; `docs/` and `mise.toml` untouched.

- [ ] **Step 2: Add dependencies**

Run: `mise exec -- flutter pub add flutter_riverpod media_kit media_kit_libs_audio file_selector ffi intl:any` then `mise exec -- flutter pub add flutter_localizations --sdk=flutter`
Expected: `Changed N dependencies!`.

- [ ] **Step 3: Write the ARB files and `l10n.yaml`**

`l10n.yaml`: `arb-dir: lib/l10n`, `template-arb-file: app_en.arb`, `output-localization-file: app_localizations.dart`, `nullable-getter: false`. Keys (en / uk); `{x}` are placeholders, `queueCount` is an ICU plural (uk forms `one`/`few`/`many`/`other`):

| key | en | uk |
|---|---|---|
| appTitle | MP3 Direct Cut | MP3 Direct Cut |
| openFolder | Open folder | Відкрити теку |
| noFolder | Open a folder with MP3 files | Відкрий теку з MP3-файлами |
| noMp3InFolder | No MP3 files in this folder | У цій теці немає MP3-файлів |
| pickFileHint | Pick a file on the left | Вибери файл ліворуч |
| notMp3 | This does not look like an MP3: no audio frames found. | Це не схоже на MP3: не знайшов жодного аудіокадру. |
| drawingWave | Drawing the waveform… | Малюю хвилю… |
| waveFailed | Could not decode the file for the waveform, but you can still cut it. | Не вдалося розкодувати файл для хвилі, але вирізати все одно можна. |
| play | ▶ Play | ▶ Грати |
| pause | ❚❚ Pause | ❚❚ Пауза |
| zoomIn | Zoom in (+) | Збільшити (+) |
| zoomOut | Zoom out (−) | Зменшити (−) |
| zoomFit | Whole file | Весь файл |
| snapToSilence | Snap to silence | Прилипати до тиші |
| selectedLabel | Selected: | Виділено: |
| selectionNone | nothing, drag across the waveform | нічого, протягни мишкою по хвилі |
| listenJoin | ▶ Listen to the join | ▶ Прослухати стик |
| deleteSelection | ✂ Delete (Del) | ✂ Видалити (Del) |
| splitAtCursor | Split here (S) | Розділити тут (S) |
| deletesTitle | To be removed | Що буде вирізано |
| deletesSummary | {count} pcs, {duration} | {count} шт., {duration} |
| deletesEmpty | Nothing yet. Select an ad on the waveform and press Del. | Поки нічого. Виділи рекламу на хвилі й натисни Del. |
| joinShort | ▶ Join | ▶ Стик |
| restore | Restore | Повернути |
| showOnWave | Show on the waveform | Показати на хвилі |
| partsTitle | Parts | Частини |
| removeSplit | Remove split | Прибрати розріз |
| outputName | Output name | Назва результату |
| durations | Was {before} · will be {after} | Було {before} · стане {after} |
| undo | Undo last (Ctrl+Z) | Скасувати останнє (Ctrl+Z) |
| hintDrag | Drag: select | Протягни мишкою: виділити |
| hintEdge | Drag a selection edge: adjust | Тягни край виділення: підправити |
| hintClick | Click: place the cursor | Клік: поставити курсор |
| hintWheel | Wheel: zoom · Shift+wheel: scroll | Колесо: зум · Shift+колесо: прокрутка |
| hintKeys | Space play · Del delete · S split · Esc clear selection | Пробіл грати · Del видалити · S розділити · Esc зняти виділення |
| queueCount | {count} file(s) in the queue | {count} файл / файли / файлів у черзі |
| apply | Apply | Застосувати |
| applying | Applying {done}/{total}… | Застосовую {done}/{total}… |
| applyResults | Written: {written} · Conflicts: {conflicts} · Errors: {errors} · Skipped: {skipped} | Записано: {written} · Конфлікти: {conflicts} · Помилки: {errors} · Пропущено: {skipped} |
| obsoleteOutputs | Earlier outputs no longer produced (left in place): {names} | Старі результати, яких більше немає (лишились на місці): {names} |
| statusDone | Done | Готово |
| statusConflict | Conflict | Конфлікт |
| statusError | Error | Помилка |
| statusStale | Source file changed | Файл-джерело змінився |
| clearStale | Mark as reviewed | Позначити перевіреним |
| conflictOutput | {name}: a different file already exists in cut/ | {name}: у cut/ вже є інший файл |
| titleNotUpdated | {name}: tags copied, title not updated | {name}: теги скопійовано, назву не оновлено |
| nameEmpty | Name is empty | Назва порожня |
| nameSlash | Name cannot contain / | Назва не може містити / |
| nameTooLong | Name is too long | Назва задовга |
| nameDuplicate | Another output has the same name | Інший результат має таку саму назву |
| queueFileBroken | The queue file was damaged; a copy was kept as {name} and a new queue started. | Файл черги пошкоджений: копію збережено як {name}, почато нову чергу. |

- [ ] **Step 4: Write the failing smoke test**

```dart
testWidgets('shows the open-folder button in Ukrainian and English', (t) async {
  for (final (locale, label) in [(const Locale('uk'), 'Відкрити теку'), (const Locale('en'), 'Open folder')]) {
    await t.pumpWidget(ProviderScope(child: App(locale: locale)));
    expect(find.text(label), findsOneWidget);
  }
});
```
(`App` takes an optional `Locale? locale` used only by tests; `HomePage` placeholder shows `openFolder`.)

- [ ] **Step 5: Run it, expect failure** — Run: `mise exec -- flutter test test/app_smoke_test.dart` → FAIL (`App` undefined).

- [ ] **Step 6: Implement** `lib/main.dart` (`MediaKit.ensureInitialized()` then `runApp(const ProviderScope(child: App()))`), `lib/app.dart`, `lib/ui/theme/cut_palette.dart`, title strings in `linux/runner/my_application.cc`.

- [ ] **Step 7: Verify** — `mise exec -- flutter test test/app_smoke_test.dart` → PASS; `mise exec -- flutter build linux --debug` → `✓ Built build/linux/x64/debug/bundle/mp3_direct_cut`.

---

### Task 2: MP3 core port (parse, keep mask, single output)

**Files:**
- Create: `lib/core/mp3/frame_header.dart`, `lib/core/mp3/mp3_layout.dart`, `lib/core/mp3/mp3_parser.dart`, `lib/core/mp3/keep_mask.dart`, `lib/core/mp3/mp3_writer.dart`, `lib/core/mp3/crc16.dart`, `lib/core/frame_range.dart`
- Create: `tool/make_fixtures.sh`, `test/fixtures/cbr_stereo_44k.mp3`, `test/fixtures/vbr_mono_22k.mp3`, `test/fixtures/plain_cbr.mp3`
- Create: `test/support/fixtures.dart`, `test/support/lame_reader.dart`
- Test: `test/core/mp3/mp3_parser_test.dart`, `test/core/mp3/keep_mask_test.dart`, `test/core/mp3/mp3_writer_test.dart`

**Interfaces:**
- Produces:
  - `class FrameRange { final int start; final int end; }` — half-open `[start, end)`, `==`/`hashCode`, `toJson() => [start, end]`, `FrameRange.fromJson(List)`.
  - `List<FrameRange> normalizeRanges(Iterable<FrameRange> ranges)` — drops empty, sorts, merges overlapping **and touching** (artifact `normalizeCuts`).
  - `FrameHeader? readFrameHeader(Uint8List b, int i, int end)` with fields `length, sampleRate, version, protection, samplesPerFrame, mono`.
  - `enum InfoKind { xing, vbri }`; `class InfoFrame { final InfoKind kind; final int offset; final int length; final int xingOffset; }` (`xingOffset` = artifact's `x`, offset of the `Xing`/`Info` tag inside the frame).
  - `class Mp3Layout { final Uint8List head; final Uint8List? tail; final int sampleRate; final int samplesPerFrame; final InfoFrame? info; final Uint32List offsets; final Uint32List lengths; final Uint16List mainDataBegin; int get frameCount; double get frameDuration; }` — public const-style constructor so tests can build synthetic layouts. `head`/`tail` are copies, not views.
  - `Mp3Layout parseMp3(Uint8List bytes)` — artifact `parseMp3`, including ID3v2 loop, ID3v1 and APE tail stripping, two-header sync, Xing/Info/VBRI detection and removal from the frame list.
  - `Uint8List deletionMask(int frameCount, List<FrameRange> deletes)` — 1 = keep.
  - `void applyReservoirRule(Uint8List keep, Uint16List mainDataBegin)` — artifact rule: for every kept frame `k ≥ 1` whose predecessor is not kept and `mainDataBegin[k] > 0`, look at `k+1 … min(n−1, k+3)`; at the first `j` with `mainDataBegin[j] == 0`, clear `k … j−1`; if none found, change nothing.
  - `Uint8List keepMask(Mp3Layout p, List<FrameRange> deletes)` = `deletionMask` + `applyReservoirRule`.
  - `int crc16(int crc, Uint8List a, int start, int end)` (poly 0xA001 table, artifact `crc16`).
  - `Uint8List buildOutput(Uint8List src, Mp3Layout p, Uint8List keep, {required Uint8List head, required Uint8List? tail, required bool keepEncoderDelay, required bool keepEndPadding})` — artifact `buildMp3` returning one contiguous file. Differences from the artifact: encoder delay (LAME bytes `q+21`, high nibble of `q+22`) is zeroed when `keepEncoderDelay` is false; end padding (low nibble of `q+22`, `q+23`) is zeroed when `keepEndPadding` is false. A VBRI frame is dropped, as in the artifact.

- [ ] **Step 1: Write `tool/make_fixtures.sh` and generate fixtures**

Source signal for all three: 10 s, 440 Hz sine at 0.5 amplitude with digital silence at 3–4 s and 7–8 s:
`aevalsrc='if(between(t,3,4)+between(t,7,8),0,0.5*sin(2*PI*440*t))'`.
- `cbr_stereo_44k.mp3`: stereo 44.1 kHz, `-c:a libmp3lame -b:a 128k -id3v2_version 3 -write_id3v1 1 -metadata title="Tale One" -metadata artist="Test Artist"`.
- `vbr_mono_22k.mp3`: mono 22.05 kHz, `-q:a 5 -id3v2_version 4 -metadata title="Казка"`.
- `plain_cbr.mp3`: stereo 44.1 kHz 128k, `-map_metadata -1 -id3v2_version 0 -write_xing 0`.

Run: `bash tool/make_fixtures.sh` → three files under `test/fixtures/`, each < 200 KB.

- [ ] **Step 2: Write failing parser tests** (`test/core/mp3/mp3_parser_test.dart`)

```dart
test('CBR stereo fixture', () {
  final p = parseMp3(fixture('cbr_stereo_44k.mp3'));
  expect(p.sampleRate, 44100); expect(p.samplesPerFrame, 1152);
  expect(p.info?.kind, InfoKind.xing);
  expect(p.frameCount, inInclusiveRange(380, 392));
  expect(ascii(p.head, 0, 3), 'ID3'); expect(ascii(p.tail!, 0, 3), 'TAG');
});
test('MPEG-2 mono VBR fixture', () {
  final p = parseMp3(fixture('vbr_mono_22k.mp3'));
  expect(p.sampleRate, 22050); expect(p.samplesPerFrame, 576); expect(p.info?.kind, InfoKind.xing);
});
test('no tags, no info frame', () {
  final p = parseMp3(fixture('plain_cbr.mp3'));
  expect(p.head, isEmpty); expect(p.tail, isNull); expect(p.info, isNull);
});
test('not an MP3', () {
  expect(parseMp3(Uint8List(0)).frameCount, 0);
  expect(parseMp3(Uint8List.fromList(utf8.encode('hello ' * 2000))).frameCount, 0);
  final src = fixture('plain_cbr.mp3');
  expect(parseMp3(Uint8List.sublistView(src, 0, 300)).frameCount, lessThan(2)); // truncated
});
test('junk between frames is skipped', () {
  // insert 100 zero bytes after frame 10 of plain_cbr → same frameCount
});
test('synthetic 1-hour file parses in under 2 s', () {
  // concatenate plain_cbr audio frames ~360 times (≈140 000 frames)
  // expect frameCount equal to the frames concatenated; Stopwatch < 2 s
});
```
`fixture(name)` and `ascii(bytes, offset, len)` live in `test/support/fixtures.dart`.

- [ ] **Step 3: Write failing keep-mask tests** (`test/core/mp3/keep_mask_test.dart`) on a synthetic layout (`n = 100`, `mainDataBegin` all 0 unless stated):

```dart
test('deleted range', () { final k = keepMask(p, [FrameRange(10, 20)]); expect(k[9], 1); expect(k.sublist(10, 20), everyElement(0)); expect(k[20], 1); });
test('reservoir: drops until a self-contained frame within 3', () { mdb[20] = 5; mdb[21] = 3; // mdb[22] == 0
  final k = keepMask(p, [FrameRange(10, 20)]); expect([k[20], k[21], k[22]], [0, 0, 1]); });
test('reservoir: gives up after 3 frames', () { for (var i = 20; i <= 23; i++) mdb[i] = 1;
  expect(keepMask(p, [FrameRange(10, 20)])[20], 1); });
test('normalizeRanges merges overlapping and touching, drops empty', () {
  expect(normalizeRanges([FrameRange(30, 40), FrameRange(5, 10), FrameRange(10, 12), FrameRange(35, 50), FrameRange(60, 60)]),
      [FrameRange(5, 12), FrameRange(30, 50)]); });
```

- [ ] **Step 4: Write failing writer tests** (`test/core/mp3/mp3_writer_test.dart`). `readLame(Uint8List file)` in `test/support/lame_reader.dart` returns `frames`, `bytes`, `delay`, `padding`, `musicLength`, `musicCrc`, `tagCrc`, `tagCrcComputed` (crc16 over the first 190 bytes of the Info frame).

```dart
test('keep everything: same audio frames, same tags', () {
  final out = buildOutput(src, p, keepAll, head: p.head, tail: p.tail, keepEncoderDelay: true, keepEndPadding: true);
  final q = parseMp3(out);
  expect(q.frameCount, p.frameCount);
  expect(audioBytes(out, q), audioBytes(src, p)); // concatenated frames
  expect(q.head, p.head); expect(q.tail, p.tail);
});
test('Xing/LAME fields describe the output', () {
  final out = buildOutput(src, p, keepMask(p, [FrameRange(100, 200)]), head: p.head, tail: p.tail, keepEncoderDelay: true, keepEndPadding: true);
  final q = parseMp3(out); final l = readLame(out);
  expect(l.frames, q.frameCount);
  expect(l.bytes, out.length - q.head.length - q.tail!.length);
  expect(l.tagCrc, l.tagCrcComputed);
  expect(l.musicCrc, crc16(0, concat(audio frames of out), 0, …));
});
test('end padding cleared, delay kept', () { /* keepEndPadding:false → padding 0, delay == source delay */ });
test('delay cleared', () { /* keepEncoderDelay:false → delay 0 */ });
```

- [ ] **Step 5: Run, expect failures** — `mise exec -- flutter test test/core/mp3` → FAIL (undefined symbols).

- [ ] **Step 6: Implement** the files listed above by porting the artifact `CORE` functions to the signatures in Interfaces.

- [ ] **Step 7: Verify** — `mise exec -- flutter test test/core/mp3` → all PASS.

---

### Task 3: Parts, naming, ID3 title, name validation

**Files:**
- Create: `lib/core/mp3/parts.dart`, `lib/core/mp3/id3_title.dart`, `lib/core/naming.dart`
- Test: `test/core/mp3/parts_test.dart`, `test/core/mp3/id3_title_test.dart`, `test/core/naming_test.dart`
- Create: `test/support/id3_reader.dart` (`String? readId3v2Title(Uint8List file)`, `String readId3v1Title(Uint8List file)`, `String? readId3v2Text(Uint8List file, String frameId)`)

**Interfaces:**
- Consumes: Task 2 `Mp3Layout`, `FrameRange`, `deletionMask`, `applyReservoirRule`, `buildOutput`.
- Produces:
  - `class PartPlan { final int index; final int anchorFrame; final int startFrame; final int endFrame; final Uint8List keep; final int keptCount; bool get isEmpty; final bool startsAtSourceStart; final bool endsAtSourceEnd; }` — `anchorFrame` is 0 for the first part, else the split frame that starts it; `startsAtSourceStart` = first kept frame is 0; `endsAtSourceEnd` = last kept frame is `frameCount − 1`.
  - `List<PartPlan> planParts(Mp3Layout p, List<FrameRange> deletes, List<int> splits)` — segments `[0, s1), [s1, s2) … [sm, n)`; each segment's mask = deletion mask restricted to the segment, then `applyReservoirRule` (frames outside the segment count as not kept, so the rule also fires at a segment start).
  - `int keptFrameTotal(List<PartPlan> parts)`.
  - `class TitledBytes { final Uint8List bytes; final bool updated; }`
  - `TitledBytes id3v2WithTitle(Uint8List head, String title)` — rewrites TIT2 of the **first** tag in `head` (other tags copied as they are). v2.3: encoding `0x01`, BOM `FF FE`, UTF-16LE, no terminator. v2.4: encoding `0x03`, UTF-8; size fields syncsafe. Keeps every other frame byte-for-byte, keeps the extended header, keeps the padding length. TIT2 missing → inserted as the first frame. `head` empty → new v2.3 tag containing only TIT2, `updated: true`. v2.2 tags or tag-level unsynchronisation flag (`0x80`) → `head` unchanged, `updated: false`.
  - `Uint8List? id3v1WithTitle(Uint8List? tail, String title)` — if every code unit of `title` ≤ 0xFF, writes it Latin-1 into bytes 3…32 (truncated to 30, zero-padded); otherwise returns `tail` unchanged. `null` stays `null`.
  - `String sourceBase(String fileName)` — strips a trailing `.mp3` (case-insensitive).
  - `List<String> outputNames({required String sourceFileName, required String? outputName, required Map<int, String> partNames, required List<PartPlan> parts})` — names without extension, one per part (including empty parts, so indices line up). One part: `outputName ?? base`. Several: `partNames[anchorFrame] ?? '${outputName ?? base} part ${index + 1}'`.
  - `enum NameProblem { empty, slash, tooLong, duplicate }`; `NameProblem? checkName(String name)` (trimmed empty; contains `/` or NUL; `utf8.encode('$name.mp3').length > 255`); duplicates are found by Task 6 across the whole queue.

- [ ] **Step 1: Failing part-planning tests** (synthetic layout, `n = 100`, all `mainDataBegin` 0 unless stated)

```dart
test('two splits make three parts', () { final ps = planParts(p, [], [30, 60]);
  expect(ps.map((x) => x.keptCount), [30, 30, 40]); expect(ps.map((x) => x.anchorFrame), [0, 30, 60]);
  expect([ps.first.startsAtSourceStart, ps.first.endsAtSourceEnd, ps.last.endsAtSourceEnd], [true, false, true]); });
test('split inside a delete range', () { final ps = planParts(p, [FrameRange(25, 35)], [30]);
  expect(ps.map((x) => x.keptCount), [25, 65]); });
test('empty part keeps its number', () { final ps = planParts(p, [FrameRange(30, 60)], [30, 60]);
  expect(ps[1].isEmpty, isTrue); expect(ps[2].index, 2); });
test('reservoir rule at a part start', () { mdb[30] = 4; final ps = planParts(p, [], [30]);
  expect([ps[1].keep[30], ps[1].keep[31]], [0, 1]); });
```

- [ ] **Step 2: Failing writer-with-parts test** on `cbr_stereo_44k.mp3`, split at frame 150: two outputs via `buildOutput(…, keepEncoderDelay: part.startsAtSourceStart, keepEndPadding: part.endsAtSourceEnd)`; reparsed frame counts equal the parts' `keptCount`; part 1 padding 0, part 2 delay 0.

- [ ] **Step 3: Failing ID3 tests**

```dart
test('v2.3: title replaced, artist kept', () { final r = id3v2WithTitle(parseMp3(cbr).head, 'Казка про Лисичку, ч. 2');
  expect(r.updated, isTrue); final f = Uint8List.fromList([...r.bytes, ...audioOf(cbr)]);
  expect(readId3v2Title(f), 'Казка про Лисичку, ч. 2'); expect(readId3v2Text(f, 'TPE1'), 'Test Artist'); });
test('v2.4: UTF-8 encoding byte', () { /* vbr_mono_22k head → TIT2 encoding byte == 0x03, text round-trips */ });
test('no tag: creates a v2.3 tag', () { final r = id3v2WithTitle(Uint8List(0), 'Їжак');
  expect(ascii(r.bytes, 0, 3), 'ID3'); expect(r.bytes[3], 3); });
test('v2.2 and unsynchronised tags untouched', () { /* hand-built 'ID3' 02 00 … and 'ID3' 03 00 80 … → same bytes, updated false */ });
test('ID3v1 Latin-1 title set, Cyrillic left alone', () {
  expect(readId3v1Title(id3v1WithTitle(tail, 'Fox Tale')!), 'Fox Tale');
  expect(id3v1WithTitle(tail, 'Казка'), tail); });
```

- [ ] **Step 4: Failing naming tests**

```dart
test('defaults', () {
  expect(outputNames(sourceFileName: 'Казки 1.mp3', outputName: null, partNames: {}, parts: one), ['Казки 1']);
  expect(outputNames(sourceFileName: 'Казки 1.MP3', outputName: null, partNames: {}, parts: three), ['Казки 1 part 1', 'Казки 1 part 2', 'Казки 1 part 3']);
  expect(outputNames(sourceFileName: 'a.mp3', outputName: 'Збірка', partNames: {}, parts: two), ['Збірка part 1', 'Збірка part 2']); });
test('part names follow their split point', () {
  // splits [30, 60], partNames {0: 'Колобок', 60: 'Ріпка'} → ['Колобок', 'a part 2', 'Ріпка']
  // splits [60] (30 removed), same partNames → ['Колобок', 'Ріпка'] });
test('checkName', () {
  expect(checkName('  '), NameProblem.empty); expect(checkName('a/b'), NameProblem.slash);
  expect(checkName('я' * 130), NameProblem.tooLong); expect(checkName("Кіт і Лис — д'Артаньян"), isNull); });
```

- [ ] **Step 5: Run, expect failures**, then **Step 6: implement** `parts.dart`, `id3_title.dart`, `naming.dart`, then **Step 7: verify** — `mise exec -- flutter test test/core` → all PASS.

---

### Task 4: Native waveform analyser (minimp3 + FFI)

**Files:**
- Create: `native/third_party/minimp3/minimp3.h`, `native/third_party/minimp3/LICENSE` (from `https://github.com/lieff/minimp3`, pin one commit hash in a comment at the top of `native/mp3_analyze.c`)
- Create: `native/mp3_analyze.c`
- Modify: `linux/CMakeLists.txt` (add the library target and install it into the bundle's `lib/`)
- Create: `lib/core/analysis/native_analyzer.dart`, `lib/core/analysis/file_analysis.dart`
- Test: `test/core/analysis/native_analyzer_test.dart`, `test/support/native_lib.dart`

**Interfaces:**
- Consumes: Task 2 `Mp3Layout`, `parseMp3`.
- Produces:
  - C: `int32_t mp3_analyze(const uint8_t *data, int64_t data_len, const uint32_t *offsets, int32_t frame_count, int32_t sample_rate, int32_t samples_per_frame, int32_t peaks_per_sec, float *rms_out, float *peaks_out, int32_t peaks_cap)` — exported with `visibility("default")`; `#define MINIMP3_ONLY_MP3`. Decodes frames **in the order of `offsets`** with one `mp3dec_t` (so the bit reservoir is honoured), passing `data + offsets[k]` and the remaining length. Writes `rms_out[k]` = RMS over all channels of frame k (samples / 32768). A frame that decodes to 0 samples counts as `samples_per_frame` samples of silence, so time stays aligned. Peaks: bucket = `globalSample * peaks_per_sec / sample_rate`, max |sample| over channels. Returns the number of peak buckets written, or −1.
  - CMake: `add_library(mp3_analyze SHARED "${CMAKE_CURRENT_SOURCE_DIR}/../native/mp3_analyze.c")`, include dir `../native/third_party/minimp3`, link `m`, `install(TARGETS mp3_analyze LIBRARY DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)`.
  - `class WaveAnalysis { final Float32List peaks; final Float32List rms; final int peaksPerSecond; final double peakScale; }` — `peakScale = 0.92 / max(peak, 1e-6)` (artifact).
  - `WaveAnalysis analyzeFrames(Uint8List bytes, Mp3Layout layout, {int peaksPerSecond = 200, String? libraryPath})` — default library path `${File(Platform.resolvedExecutable).parent.path}/lib/libmp3_analyze.so`.
  - `class FileAnalysis { final String path; final int size; final int mtimeMs; final Mp3Layout layout; final WaveAnalysis? wave; final Object? waveError; }` (`layout.frameCount == 0` means "not an MP3").
  - `Future<FileAnalysis> analyzeFile(String path, {String? libraryPath})` — `Isolate.run`: read bytes, `parseMp3`, `analyzeFrames`; a native failure sets `waveError` and leaves `wave` null (cutting still works, artifact behaviour).

- [ ] **Step 1: Vendor minimp3** — download `minimp3.h` and `LICENSE` at a pinned commit into `native/third_party/minimp3/`.

- [ ] **Step 2: Failing tests.** `test/support/native_lib.dart` compiles the library once per run: `cc -shared -fPIC -O2 -Inative/third_party/minimp3 -o .dart_tool/test_native/libmp3_analyze.so native/mp3_analyze.c -lm` and returns the path.

```dart
test('one RMS value per frame', () { final w = analyzeFrames(src, p, libraryPath: lib); expect(w.rms.length, p.frameCount); });
test('silence at 3–4 s is quiet, tone at 1.5 s is loud', () {
  final k = (3.5 / p.frameDuration).round(); expect(w.rms[k], lessThan(0.01));
  expect(w.rms[(1.5 / p.frameDuration).round()], greaterThan(0.1)); });
test('peak count matches duration', () {
  expect(w.peaks.length, closeTo(p.frameCount * p.samplesPerFrame * 200 / p.sampleRate, 1)); });
test('analyzeFile runs in an isolate and matches the sync result', () async { /* same rms */ });
test('missing library → waveError set, layout still parsed', () async { /* libraryPath: 'nope.so' */ });
```

- [ ] **Step 3: Run, expect failures**, **Step 4: implement**, **Step 5: verify** — `mise exec -- flutter test test/core/analysis` → PASS; `mise exec -- flutter build linux --debug` and `ls build/linux/x64/debug/bundle/lib/libmp3_analyze.so` → file exists.

---

### Task 5: Queue model, persistence, undo

**Files:**
- Create: `lib/state/queue_entry.dart`, `lib/state/queue_store.dart`, `lib/state/queue_controller.dart`, `lib/state/folder_controller.dart`
- Test: `test/state/queue_store_test.dart`, `test/state/queue_controller_test.dart`

**Interfaces:**
- Consumes: `FrameRange`, `normalizeRanges`.
- Produces:
  - `enum EntryStatus { pending, done, conflict, error }`; `enum OutputResult { written, conflict, error, skippedEmpty }`.
  - `class OwnOutput { final String name; final int size; final int mtimeMs; }` (`name` includes `.mp3`).
  - `class OutputRecord { final String name; final OutputResult result; final bool titleUpdated; final String? message; }`
  - `class QueueEntry { final String fileName; final int sourceSize; final int sourceMtimeMs; final List<FrameRange> deletes; final List<int> splits; final String? outputName; final Map<int, String> partNames; final EntryStatus status; final List<OwnOutput> ownOutputs; final List<OutputRecord> results; final List<String> obsolete; bool get hasWork; QueueEntry copyWith(…); Map<String, Object?> toJson(); factory QueueEntry.fromJson(Map<String, Object?>); }` — `hasWork` = any delete, split, output name or part name.
  - JSON shape: `{"version": 1, "entries": {"<fileName>": {"size", "mtimeMs", "deletes": [[a,b]], "splits": [k], "name", "partNames": {"<anchor>": "…"}, "status", "ownOutputs": [{"name","size","mtimeMs"}], "results": [{"name","result","titleUpdated","message"}], "obsolete": ["…"]}}}`.
  - `class QueueLoad { final Map<String, QueueEntry> entries; final String? brokenBackupName; }`
  - `class QueueStore { Future<QueueLoad> load(Directory folder); Future<void> save(Directory folder, Map<String, QueueEntry> entries); }` — `save` writes `.mp3directcut-queue.json.tmp` then renames over `.mp3directcut-queue.json`. `load` of unparsable JSON or `version` ≠ 1 renames the file to `.mp3directcut-queue.broken-<yyyyMMdd-HHmmss>.json`, returns empty entries and that name. Missing file → empty.
  - `final queueStoreProvider = Provider<QueueStore>((ref) => QueueStore());`
  - `class Mp3FileInfo { final String name; final int size; final int mtimeMs; }`
  - `class FolderState { final Directory dir; final List<Mp3FileInfo> files; }`; `final folderProvider = NotifierProvider<FolderController, FolderState?>(…)` with `Future<void> open(String path)` (lists top-level `*.mp3`, case-insensitive, natural sort so `Казка 2` < `Казка 10`, then loads the queue) and `Future<void> refresh()`.
  - `final folderPickerProvider = Provider<Future<String?> Function()>((ref) => () => getDirectoryPath());` (overridable in tests).
  - `class QueueState { final Map<String, QueueEntry> entries; final String? brokenBackupName; bool isStale(String fileName); }` — stale = entry's `sourceSize`/`sourceMtimeMs` differ from the folder listing.
  - `final queueProvider = NotifierProvider<QueueController, QueueState>(…)`, methods (all `fileName`-scoped): `addDelete(String f, FrameRange r)`, `removeDelete(String f, int index)`, `addSplit(String f, int frame, int frameCount)` (ignores `frame ≤ 0`, `frame ≥ frameCount`, duplicates), `removeSplit(String f, int frame)`, `setOutputName(String f, String? name)`, `setPartName(String f, int anchor, String? name)`, `undo(String f)`, `bool canUndo(String f)`, `clearStale(String f)`, `Future<void> flush()`, `void replaceEntries(Map<String, QueueEntry>)` (used by Apply). Any edit of marks or names sets `status` to `pending`. An entry whose `hasWork` becomes false is removed unless `ownOutputs` is non-empty. Undo history is in memory only (snapshots of `deletes`, `splits`, `outputName`, `partNames`). Saves are debounced 300 ms; `flush()` is called from an `AppLifecycleListener.onExitRequested` in `App`.
  - Empty and blank names passed to `setOutputName` / `setPartName` are stored as `null`.

- [ ] **Step 1: Failing store tests** — round-trip of a full entry; atomic save leaves no `.tmp`; `'{oops'` → empty entries, `brokenBackupName` matches `^\.mp3directcut-queue\.broken-\d{8}-\d{6}\.json$`, the backup holds `'{oops'`, and the original name no longer exists; `{"version": 2}` → same backup behaviour.

- [ ] **Step 2: Failing controller tests** (`ProviderContainer` with `folderProvider` opened on a temp copy of the fixtures)

```dart
test('deletes merge', …);             // add [10,20) then [15,30) → [[10,30)]
test('splits validated', …);           // 0, frameCount, duplicate ignored; sorted
test('undo restores marks and names', …);
test('editing a done entry makes it pending', …);
test('entry without work disappears unless it has own outputs', …);
test('persists and reloads', …);       // flush → new container → same entries
test('stale after the source changes; clearStale fixes it', …); // setLastModifiedSync on the source
test('folder lists only top-level mp3, natural order', …); // with a subfolder containing an mp3 and a .txt
```

- [ ] **Step 3: Run, expect failures**, **Step 4: implement**, **Step 5: verify** — `mise exec -- flutter test test/state` → PASS.

---

### Task 6: Apply runner

**Files:**
- Create: `lib/core/apply/apply_runner.dart`, `lib/state/apply_controller.dart`
- Test: `test/core/apply/apply_runner_test.dart`, `test/state/apply_controller_test.dart`

**Interfaces:**
- Consumes: Tasks 2, 3, 5 (`parseMp3`, `planParts`, `buildOutput`, `id3v2WithTitle`, `id3v1WithTitle`, `outputNames`, `checkName`, `QueueEntry`).
- Produces:
  - `Map<String, List<(String output, NameProblem problem)>> validateQueue(Map<String, QueueEntry> entries, Map<String, Mp3Layout> layouts)` — `checkName` per output plus `NameProblem.duplicate` for any output name produced by more than one entry/part across the whole queue (case-sensitive, Linux).
  - `QueueEntry applyEntrySync(Directory folder, QueueEntry entry)` — pure `dart:io` sync, safe in `Isolate.run`. Steps: source missing or size/mtime ≠ recorded → `status: error`, message; parse; `planParts`; names; for each non-empty part: target `cut/<name>.mp3`; if it exists and is not an own output with matching size and mtime → `OutputResult.conflict` (file untouched); else write `cut/.<name>.mp3.tmp` and rename over the target, record `OwnOutput` with the new size/mtime. Title: entry has `outputName`, any `partNames` or any split → `id3v2WithTitle`/`id3v1WithTitle` with the output name; otherwise tags unchanged. Empty part → `OutputResult.skippedEmpty`. `obsolete` = own outputs not produced this run (never deleted, stay in `ownOutputs`). Status: all non-empty outputs written → `done`; any conflict → `conflict`; any error → `error`.
  - `class ApplyState { final bool running; final int done; final int total; final ApplySummary? summary; }`, `class ApplySummary { final int written, conflicts, errors, skipped; final List<String> obsolete; }`
  - `final applyProvider = NotifierProvider<ApplyController, ApplyState>(…)` with `Future<void> applyAll()` — runs entries that are `hasWork`, not `done`, not stale and pass validation, one `Isolate.run(applyEntrySync)` at a time, updating progress and the queue via `replaceEntries`, then `flush()`. Validation failures and stale entries count as `skipped`.

- [ ] **Step 1: Failing runner tests** (temp folder with `cbr_stereo_44k.mp3` copied as `Казка.mp3`)

```dart
test('deletes only → cut/Казка.mp3, original untouched', …);       // sha of source equal before/after; tags unchanged
test('split → part files with titles', …);                           // 'Казка part 1.mp3', 'Казка part 2.mp3'; readId3v2Title == file base
test('conflict is per part', …);                                     // pre-made cut/Казка part 2.mp3 'foreign' → parts 1 and 3 written, part 2 conflict, foreign bytes unchanged, status conflict
test('own outputs are overwritten on re-apply', …);                  // apply → done; edit (pending) → apply → written, no conflict
test('own output changed by the user is a conflict', …);             // append a byte to cut/Казка.mp3 before re-apply
test('obsolete own outputs are listed, not deleted', …);             // remove a split → old part 2 listed in obsolete, still on disk
test('missing source → error', …);
test('no temp files left', …);                                       // no file in cut/ starting with '.'
```

- [ ] **Step 2: Failing controller tests** — two entries, one with a `/` in its name: only the valid one runs, summary `skipped: 1`; a `done` entry is skipped; a stale entry is skipped; a missing source on the first entry does not stop the second.

- [ ] **Step 3: Run, expect failures**, **Step 4: implement**, **Step 5: verify** — `mise exec -- flutter test test/core/apply test/state/apply_controller_test.dart` → PASS.

---

### Task 7: Home layout, file panel, queue bar

**Files:**
- Create: `lib/ui/home_page.dart`, `lib/ui/file_panel.dart`, `lib/ui/queue_bar.dart`, `lib/state/selection_controller.dart`
- Modify: `lib/app.dart` (real `HomePage`)
- Test: `test/ui/file_panel_test.dart`

**Interfaces:**
- Consumes: `folderProvider`, `folderPickerProvider`, `queueProvider`, `applyProvider`, `analyzeFile`.
- Produces:
  - `final selectedFileProvider = NotifierProvider<SelectedFileController, String?>(…)` with `select(String? fileName)`.
  - `final fileAnalysisProvider = FutureProvider.family<FileAnalysis, String>((ref, path) => analyzeFile(path))` (kept alive; overridable in tests).
  - `HomePage`: left `FilePanel` (fixed 300 px, open-folder button, folder path, file list), right the editor area (placeholder text `pickFileHint` until Task 10), bottom `QueueBar` (`queueCount`, Apply button disabled while running or when nothing is pending, progress `applying`, summary `applyResults`, `obsoleteOutputs`, and a banner for `queueFileBroken`).
  - File row: name; icons with counts for deletes (`Icons.content_cut`), splits (`Icons.call_split`), renamed (`Icons.drive_file_rename_outline`); status chip (`statusDone` / `statusConflict` / `statusError` / `statusStale`); a stale row also has a `clearStale` button calling `queueProvider.clearStale`; "not an MP3" rows (analysis `frameCount == 0`) are shown greyed with `notMp3` as tooltip and cannot be selected.
  - After Apply, `QueueBar` can expand a list of per-output messages from the entries' `results`: `conflictOutput` for conflicts, `titleNotUpdated` for `titleUpdated == false` on written outputs that needed a new title, and error messages.

- [ ] **Step 1: Failing widget tests** (override `folderPickerProvider` to return a temp folder with two fixtures, one `broken.mp3` of 10 text bytes and a subfolder with an mp3; override `fileAnalysisProvider` with a fake)

```dart
testWidgets('opens a folder and lists only its top-level mp3 files', …); // 3 rows, subfolder file absent
testWidgets('broken mp3 is greyed and not selectable', …);
testWidgets('row shows queue counts and status', …);                       // seed queue entry: 2 deletes, 1 split, done → '2', '1', 'Готово'
testWidgets('Apply disabled with nothing pending', …);
testWidgets('stale row clears with the button', …);                         // change source mtime → 'Файл-джерело змінився' → tap clearStale → chip gone
```

- [ ] **Step 2: Run, expect failures**, **Step 3: implement**, **Step 4: verify** — `mise exec -- flutter test test/ui/file_panel_test.dart` → PASS.

---

### Task 8: Waveform, overview, selection, zoom, snap

**Files:**
- Create: `lib/core/time_format.dart`, `lib/core/snap.dart`, `lib/ui/editor/view_window.dart`, `lib/state/editor_controller.dart`, `lib/ui/editor/wave_painter.dart`, `lib/ui/editor/waveform_view.dart`, `lib/ui/editor/overview_strip.dart`
- Test: `test/core/time_format_test.dart`, `test/core/snap_test.dart`, `test/ui/editor/view_window_test.dart`, `test/ui/editor/waveform_view_test.dart`

**Interfaces:**
- Consumes: `FileAnalysis`, `queueProvider` (deletes and splits to draw), `CutPalette`.
- Produces:
  - `String formatTime(double seconds, {bool millis = true})` — artifact `fmt` (`1:05.250`, `1:02:03.000`, no-millis `1:05`).
  - `double niceStep(double spanSeconds, double widthPx)` — artifact `niceStep` (steps list and 90 px rule).
  - `int snapToFrame(double t, double frameDuration, int frameCount)`; `int snapToQuiet(double t, Float32List rms, double frameDuration, int frameCount, {double radiusSeconds = 0.3})` — artifact `snapQuiet`, returning a frame boundary index.
  - `class ViewWindow { final double start; final double span; ViewWindow clamp(double duration); ViewWindow zoomAt(double t, double factor, double duration); ViewWindow pan(double deltaSeconds, double duration); double xToT(double x, double width); double tToX(double t, double width); }` — minimum span 0.05 s (artifact `clampView`).
  - `class EditorState { final String? fileName; final ViewWindow view; final (double, double)? selection; final double cursor; final bool snapToSilence; }`
  - `final editorProvider = NotifierProvider<EditorController, EditorState>(…)` with `reset(FileAnalysis a)` (whole file view, no selection, cursor 0, snap kept), `setView`, `setSelection((double, double)? s)`, `setCursor(double t)`, `toggleSnap()`, `zoomIn()` (factor 0.5 at selection centre or view centre), `zoomOut()` (2 at view centre), `zoomFit()`, `zoomTo(double a, double b)` (pad = max(1 s, 0.5·len), artifact cut-list click).
  - `WaveformView` (230 px tall, ruler 22 px): `CustomPaint` + `Listener` + `MouseRegion`, behaviour exactly as the artifact's pointer handlers — new drag after 4 px movement, edge drag within 7 px with `SystemMouseCursors.resizeLeftRight`, click without movement sets cursor (and seeks, via a callback `onSeek(double t)`) and clears selection, release snaps (`snapToQuiet` for new selections when snap is on, `snapToFrame` for edges or when off), selections shorter than half a frame are dropped; wheel zooms at pointer with factor `exp(dy · 0.0025)`; Shift+wheel or horizontal wheel pans. Draws deletes (fill + X lines + edges in `cut`), selection (`selFill` + 2 px edges in `sel`), split points (2 px lines in `split` across the full height), playhead (`playhead`, 2 px), ruler labels.
  - `OverviewStrip` (40 px): whole-file wave at 0.7 opacity, deletes, split points, view rectangle, playhead; pointer down/move centres the view.
  - The playhead position comes from a `double Function()` (Task 9 supplies it; tests pass a constant).

- [ ] **Step 1: Failing pure tests**

```dart
expect(formatTime(65.25), '1:05.250'); expect(formatTime(3723), '1:02:03.000'); expect(formatTime(65.9, millis: false), '1:05');
expect(niceStep(600, 1000), 60); expect(niceStep(2, 1000), 0.2);
// snapToQuiet on rms with a quiet frame 5 frames from t → returns that boundary; beyond 0.3 s → ignored
// ViewWindow.zoomAt keeps the time under the pointer at the same x; clamp keeps span ≥ 0.05 and inside duration
```

- [ ] **Step 2: Failing widget tests** (fake analysis: 1000 frames, `fd = 0.026`, rms quiet at frames 400–410)

```dart
testWidgets('drag selects and snaps to silence', …);    // drag 100→300 px → selection edges at frame boundaries; an edge near frame 405 lands in 400–410
testWidgets('click sets cursor and clears selection', …);
testWidgets('dragging an edge adjusts the selection', …);
testWidgets('wheel zooms around the pointer', …);
```

- [ ] **Step 3: Run, expect failures**, **Step 4: implement**, **Step 5: verify** — `mise exec -- flutter test test/core test/ui/editor` → PASS.

---

### Task 9: Playback

**Files:**
- Create: `lib/audio/audio_engine.dart`, `lib/audio/media_kit_engine.dart`, `lib/state/playback_controller.dart`
- Test: `test/state/playback_controller_test.dart`

**Interfaces:**
- Consumes: `queueProvider` (deletes), `selectedFileProvider`, `FileAnalysis` (frame duration).
- Produces:
  - `abstract class AudioEngine { Future<void> open(String path); Future<void> play(); Future<void> pause(); Future<void> seek(double seconds); double get position; bool get playing; Stream<bool> get playingStream; Future<void> dispose(); }`
  - `MediaKitEngine implements AudioEngine` — one `Player`; after creation set mpv property `hr-seek` to `yes` via `(player.platform as NativePlayer).setProperty`; `open` uses `Media(path)` with `play: false`; `position` reads `player.state.position`.
  - `final audioEngineProvider = Provider<AudioEngine>((ref) => MediaKitEngine())` (tests override with a fake).
  - `double? skipTarget(double t, List<(double, double)> skips)` — returns `b` if `a − 0.01 ≤ t < b` for some skip (artifact `tick`).
  - `final playbackProvider = NotifierProvider<PlaybackController, PlaybackState>(…)`; `PlaybackState { bool playing; }`; methods `togglePlay()`, `seek(double t)`, `listenJoin(double a, double b)` (play from `a − 2` to `b + 2`, skipping `[a, b)` once), `void tick()` — called every frame by a `Ticker` in the editor: applies `skipTarget` over the file's deletes (+ the temporary join skip), stops at `stopAt`, and moves the editor view when the playhead leaves `[start, start + 0.95·span]` (`start = t − 0.1·span`).
  - Selecting another file pauses and opens it.

- [ ] **Step 1: Failing tests** with `FakeAudioEngine` (manually advanced `position`)

```dart
test('skipTarget', () { expect(skipTarget(5.0, [(4.0, 6.0)]), 6.0); expect(skipTarget(3.995, [(4.0, 6.0)]), 6.0); expect(skipTarget(6.0, [(4.0, 6.0)]), isNull); });
test('playing skips deletes', …);         // position 4.5 → tick → seek(6.0)
test('listenJoin plays a−2..b+2 and stops', …); // seek(a−2) + play; position b+2 → tick → paused, temp skip cleared
test('view follows the playhead', …);
```

- [ ] **Step 2: Run, expect failures**, **Step 3: implement**, **Step 4: verify** — `mise exec -- flutter test test/state/playback_controller_test.dart` → PASS.

---

### Task 10: Editor panel, lists, rename, shortcuts

**Files:**
- Create: `lib/ui/editor/editor_pane.dart`, `lib/ui/editor/editor_toolbar.dart`, `lib/ui/editor/selection_bar.dart`, `lib/ui/editor/deletes_list.dart`, `lib/ui/editor/parts_list.dart`, `lib/ui/editor/editor_shortcuts.dart`
- Modify: `lib/ui/home_page.dart` (editor area)
- Test: `test/ui/editor/editor_pane_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 5, 7, 8, 9.
- Produces (layout in artifact order):
  - Header: file name; when the file has no split points, an `outputName` text field (hint = original base).
  - Toolbar: play/pause, clock (`formatTime(position)`, tabular figures, monospace), zoom −/+, `zoomFit`, `snapToSilence` checkbox.
  - `WaveformView` + `OverviewStrip`; while analysing show `drawingWave`; `waveError` → `waveFailed` text instead of the wave (selection and cutting still work on frame time).
  - Selection bar: `selectedLabel` + `start – end (length)` or `selectionNone`; `listenJoin` and `deleteSelection` enabled only with a selection; `splitAtCursor` always enabled when a file is open.
  - Deletes list (`deletesTitle`, `deletesSummary`, `deletesEmpty`): index, range (tap → `zoomTo`, tooltip `showOnWave`), `joinShort`, `restore`.
  - Parts list (only when there are split points, `partsTitle`): one row per part with its time range (after deletes), a name field (hint = default name from `outputNames`, saved via `setPartName` keyed by the part's `anchorFrame`), and `removeSplit` for parts 2…N. Name problems from `checkName` shown under the field.
  - Totals: `durations` with before = `frameCount · fd`, after = `keptFrameTotal(planParts(…)) · fd` (no millis); `undo` button enabled by `canUndo`.
  - Hints line (`hintDrag`, `hintEdge`, `hintClick`, `hintWheel`, `hintKeys`).
  - `EditorShortcuts` — a `Focus` around the editor handling `KeyDownEvent` by `physicalKey`: `space` toggle play; `delete`/`backspace` delete selection; `keyZ` + Ctrl undo; `escape` clear selection; `equal`/`numpadAdd` zoom in; `minus`/`numpadSubtract` zoom out; `digit0`/`numpad0` fit; `keyS` split at cursor (snapped like a new selection edge). Ignored while a `TextField` has focus (the field consumes the event first; verify).
  - Delete adds `FrameRange(round(a / fd), round(b / fd))` via `addDelete` and clears the selection; Split adds the snapped frame via `addSplit`.

- [ ] **Step 1: Failing widget tests** (fake analysis and fake audio engine)

```dart
testWidgets('select + Del adds a delete and clears the selection', …);
testWidgets('S adds a split at the cursor and shows the parts list', …); // two part rows, hints 'X part 1', 'X part 2'
testWidgets('part name is saved for its anchor', …);
testWidgets('Ctrl+Z undoes the last mark', …);
testWidgets('typing 0 and S in a name field does not trigger shortcuts', …);
testWidgets('totals show before and after', …);                         // 1000 frames · 0.026 = 0:26; delete 100 frames → 0:23
testWidgets('Restore removes a delete', …);
```

- [ ] **Step 2: Run, expect failures**, **Step 3: implement**, **Step 4: verify** — `mise exec -- flutter test test/ui` → PASS.

---

### Task 11: Whole-app verification

- [ ] **Step 1:** `mise exec -- flutter analyze` → `No issues found!`
- [ ] **Step 2:** `mise exec -- flutter test` → all tests pass.
- [ ] **Step 3:** `mise exec -- flutter build linux --release` → `✓ Built build/linux/x64/release/bundle/mp3_direct_cut`; `build/linux/x64/release/bundle/lib/libmp3_analyze.so` exists.
- [ ] **Step 4: Manual run on a copy of a real folder** (ask the user for one; work on a copy): open folder; mark deletes in two files, a split with names in a third, a rename in a fourth; close and reopen the app → marks restored; Apply → `cut/` holds exactly the expected names, originals' checksums unchanged; for each output `ffprobe -v error -show_entries format=duration:format_tags=title -of default=nw=1 "<file>"` shows the duration within 0.05 s of the app's "will be" and the expected title; play each output's joins by ear; re-Apply → nothing written (all done); edit one entry → re-Apply overwrites only its own outputs.
