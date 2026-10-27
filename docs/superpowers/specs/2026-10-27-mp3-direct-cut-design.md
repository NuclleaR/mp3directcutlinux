# MP3 Direct Cut — design

Date: 2026-10-27
Status: approved 2026-10-27

## Intent

The user strips ads and outros from a folder of audio fairy tales (~50 MP3s) and splits
1-hour+ files that contain 3–5 tales into one file per tale. Today they do it with a
single-file browser tool ("MP3 Ножиці", source in
[docs/reference/mp3-nozhytsi-artifact.html](../../reference/mp3-nozhytsi-artifact.html)),
one file at a time, which is too slow.

MP3 Direct Cut is a native Linux Flutter app that does the same lossless frame-level
cutting, but for a whole folder: mark every file first, then apply everything in one go.

## Goals

- Open a folder; a **left panel** lists every `.mp3` in it (top level only).
- Clicking a file shows its frame waveform with **every feature of the artifact**
  (see "Artifact parity" below).
- Two marking actions on the waveform:
  - **Delete**: mark the selected range for removal (exactly as in the artifact).
  - **Split**: mark a split point at the cursor position.
- **Rename**: set the output name of a file; a split file gets **one name per part**.
- A **work queue** with **one entry per file** holding everything to do with that file:
  delete ranges, split points, output names. Every edit updates that file's entry.
- **Apply** processes the whole queue in one go.
- The queue survives closing the app: it is stored as a JSON file in the opened folder
  and restored when that folder is opened again.

## Non-goals

- Subfolders (not now).
- Re-encoding, effects, volume changes, fades.
- Formats other than MPEG-1/2 Layer III (what the artifact parses).
- Other platforms than Linux.
- Drag and drop of files or folders onto the window (the folder opens via a button only).

## Anti-goals (failure even if it "works")

- Touching the originals in any way. Output only goes to the `cut/` subfolder.
- Re-encoding audio.
- Losing marks the user made (closing the app, switching files, a failed Apply).
- Silently overwriting a file that already exists in `cut/`.

## Decided by the user

### Output

- Results go to `<opened folder>/cut/` (created if missing). Originals are never modified.
- Default naming when the entry has no names set:
  - no split points → `<original name>.mp3`
  - with split points → `<original name> part 1.mp3` … `<original name> part N.mp3`
- If the entry has names set, they replace the defaults (file name, or per part).
- If an output file already exists in `cut/` and the app did not write it itself:
  **skip that output, do not write it**, and show the entry as a conflict.
  For a split file this is **per part**: the other parts are still written, and the
  entry shows which parts conflicted.

### After Apply

- A successfully applied entry **stays in the queue with status "done"**, keeping all its
  marks; the next Apply skips it.
- Editing the marks or names of a "done" entry puts it back to pending.
- The app remembers in the queue JSON which files in `cut/` it wrote for each entry.
  When a pending entry is applied again, the app **may overwrite its own earlier
  outputs** for that entry. Any other existing file is a conflict as above.
- Results (done / conflict / error, and per part for split files) are stored in the queue
  JSON, so they are still visible after a restart.

### Interface language

- **Ukrainian and English**, chosen from the system locale, via `flutter_localizations`,
  `intl` and ARB files (`flutter gen-l10n`). The window title stays "MP3 Direct Cut".

### ID3 tags

- Copy the original's tags into every output file, and set **Title** to the output's
  new name (the file name without `.mp3`).

### Queue persistence

- Stored as JSON (the user allowed YAML or JSON; JSON chosen because `dart:convert`
  reads and writes it with no extra package) in the opened folder.

### Stack

- Flutter 3.47.8 (pinned via `mise.toml` in the project root, with cmake and ninja),
  Linux desktop only, project in the repository root, package `mp3_direct_cut`,
  org `com.example` → application id `com.example.mp3_direct_cut`.
  Window title: "MP3 Direct Cut".
- State: **Riverpod** (`flutter_riverpod`, no code generation).
- Playback: **media_kit** (libmpv, already installed on the machine).
- Waveform/silence decoding: **minimp3** (single-header C, CC0) vendored into the
  project, built by the Linux CMake build, called through `dart:ffi`.
- Folder picker: **file_selector** (official flutter.dev plugin, GTK dialog).
- Cutting itself: pure Dart, a port of the artifact's `CORE` block.
- Localisation: `flutter_localizations` (SDK) and `intl`.

## Artifact parity

Everything the artifact does stays, adapted to the folder workflow:

- Play / pause (`Space`), clock `m:ss.mmm`, playhead that the view follows
  (re-centres when the playhead passes 95% of the view).
- While playing, marked delete ranges are skipped.
- Zoom in / out / whole file (`+`, `-`, `0`); mouse wheel zooms at the pointer;
  `Shift`+wheel or horizontal wheel pans.
- Time ruler with "nice" steps.
- Overview strip under the waveform: whole-file wave, delete ranges, the visible
  window as a rectangle, click/drag to move the view.
- Drag to select; drag a selection edge (7 px hit zone) to adjust; click to place the
  cursor (seek) and clear the selection; `Esc` clears the selection.
- "Snap to silence" checkbox (on by default): a new selection's edges snap to the
  quietest frame boundary within ±0.3 s using per-frame RMS; dragging an edge snaps to
  the nearest frame boundary.
- Delete (`Del` / `Backspace`): add the selection to the delete ranges; overlapping or
  touching ranges merge.
- "Listen to the join": play from `a − 2 s` to `b + 2 s`, skipping `[a, b]`, both for the
  current selection and for each listed delete range.
- List of delete ranges: index, time range (click → zoom to it), ▶ join, "Restore".
- Undo (`Ctrl+Z`), per file.
- Duration before / after, where "after" uses the same keep mask Apply will use
  (including the bit-reservoir adjustment).
- Light and dark theme following the system, using the artifact's palette.
- The artifact's "open file", "another file" and "save MP3" controls are replaced by the
  left panel, the queue and Apply.

## New behaviour beyond the artifact

- **Split** button with a keyboard shortcut. Split points are drawn on the waveform and
  the overview as vertical markers in their own colour, and can be removed.
- A parts list for split files: one row per part with its time range and an editable
  name (placeholder = the default name).
- A rename field for files without split points (placeholder = original name).
- Left panel rows show whether the file has a queue entry and what is in it
  (deletes / splits / renamed), and after Apply its result (written / conflict / error).
- A queue summary with the **Apply** button, progress while applying, and a results
  summary at the end.

## Builder's calls (made by Claude, open to the user's veto)

- Queue file name: `.mp3directcut-queue.json` in the opened folder (hidden, so it does
  not clutter the folder).
- Queue entries store positions as **frame indices** (exact) rather than seconds, plus the
  source file's size and modification time; an entry whose source changed is flagged
  as stale and not applied until the user reviews it.
- The queue file is rewritten after every change (debounced).
- Split snaps like a new selection edge: to the quietest frame boundary within ±0.3 s
  when "snap to silence" is on, otherwise to the nearest frame boundary.
- Split shortcut: `S`.
- A split point that falls inside a delete range splits at that range's end.
  A part that ends up with no frames is not written; numbering still follows the
  split points so names stay attached to the right parts.
- The start of every output part gets the same bit-reservoir treatment the artifact
  applies after a cut (drop up to 3 frames until one with `main_data_begin == 0`).
- Xing/Info + LAME header is rebuilt per output part (frame count, byte count, TOC,
  CRCs). LAME encoder delay is kept only if the part starts at the source's first audio
  frame; LAME end padding is kept only if the part ends at the source's last audio frame.
- If renaming adds a name to a file that is later split, the file-level name becomes the
  base for default part names (`<new name> part N`).
- ID3v2 Title is rewritten in place (TIT2, UTF-16 for v2.3, UTF-8 for v2.4; added if
  missing). If the original has no ID3v2 tag, a minimal ID3v2.3 tag with TIT2 is
  created. ID3v1 title (30 bytes, Latin-1) is set only if the name fits Latin-1,
  otherwise the ID3v1 title is left as in the original.
- When an entry has no rename and no split, tags are copied unchanged.
- "Own earlier output" means a file listed in the entry's JSON record whose size and
  modification time still match what was recorded; if the user replaced or edited it,
  it counts as someone else's file (conflict).
- Own earlier outputs that a re-applied entry no longer produces (a part removed or
  renamed) are **never deleted**; the results summary lists them as obsolete.
- Undo covers deletes, split points and names, per file.
- Names are validated before Apply: no `/`, no empty names, no two outputs in the
  queue with the same name. Entries that fail validation are not applied and show why.
- A part's name is attached to the split point that starts it (part 1 to the file start),
  so adding or removing another split point does not move names between tales.
- Stale entries (source size or mtime changed) are shown with a warning and skipped by
  Apply until the user clears the warning.
- Keyboard shortcuts use physical keys, so they work on the Ukrainian layout too.
- Unsupported system locale falls back to English.
- Decoding for the waveform runs in a background isolate and streams through the file
  (no full PCM in memory — a 1-hour stereo file would be over 1 GB as floats), producing
  peaks at 200 per second and one RMS value per MP3 frame.

## Left to the builder

- Widget structure, provider layout, file/folder structure under `lib/`.
- Exact layout of the main area (the artifact's column order is the starting point:
  toolbar, waveform + overview, selection bar, lists, totals/undo, hints).
- How playback position is polled for precise skipping over delete ranges.
- How test fixture MP3s are produced and stored.

## TODO (for approval)

1. Scaffold the Flutter project (Linux only), set the window title, add the approved
   dependencies (`flutter_riverpod`, `media_kit` + its audio libs for Linux,
   `file_selector`, `ffi`, `flutter_localizations`, `intl`), set up `gen-l10n` with
   Ukrainian and English ARB files.
2. Port the artifact's MP3 core to Dart (frame parser, keep mask with bit-reservoir
   rule, output builder with Xing/LAME fix-up) with unit tests.
3. Extend the core: split into parts, per-part LAME delay/padding, ID3 Title rewrite;
   tests.
4. Native decoder: vendor minimp3, add the CMake target, FFI binding; peaks + per-frame
   RMS in a background isolate.
5. Queue model in Riverpod: entries (deletes, splits, names), per-file undo, JSON
   persistence in the folder, stale-source detection, entry status and the record of
   own outputs.
6. Left panel: folder picker, MP3 list, per-file queue/result indicators.
7. Waveform view: wave, ruler, overview, mouse selection/edges/click/wheel, zoom,
   snap to silence, theme.
8. Playback via media_kit: play/pause, clock, playhead follow, skip deletes,
   listen to the join.
9. Editing panel: Delete and Split, delete-range list, parts list with names, rename
   field, durations before/after, undo, keyboard shortcuts.
10. Apply: validate names, process pending entries into `cut/`, overwrite own outputs,
    skip conflicting outputs per part, mark entries done, progress and results summary
    (including obsolete own outputs).
11. Verify: `flutter analyze`, tests, Linux build, and a manual run on a real folder.
