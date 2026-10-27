# MP3 Direct Cut

A Linux desktop app for cutting ads and outros out of MP3 files and splitting long files
into parts, across a whole folder at once. It works on MP3 frames directly, so nothing is
re-encoded and the audio quality stays exactly as it was.

Built for a folder of audio fairy tales: about fifty files that each need an ad or an outro
removed, and hour-long files holding three to five tales that need splitting.

## Features

- Open a folder; its MP3 files are listed on the left (subfolders are not included).
- Click a file to see its waveform, with an overview strip for long files.
- Select a range with the mouse and mark it for deletion, or split the file at the playhead.
- Give the output a new name; every part of a split file gets its own name.
- Listen before you cut: playback skips marked ranges, and "Listen to the join" plays two
  seconds either side of a cut.
- Snap selections to silence, zoom, undo.
- Every mark goes into a work queue, one entry per file, saved in the folder as
  `.mp3directcut-queue.json`, so you can close the app and continue later.
- **Apply** processes the whole queue and writes the results into `<folder>/cut/`. The
  original files are never changed.
- ID3 tags are copied from the original, with the title set to the new name.
- Files already in `cut/` that the app did not write are left alone and reported as
  conflicts.
- Interface in English and Ukrainian.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/NuclleaR/mp3directcutlinux/main/install.sh | bash
```

This installs the newest release for the current user, with no sudo:

- the app in `~/.local/share/mp3-direct-cut`;
- the `mp3-direct-cut` command in `~/.local/bin`;
- a menu entry with its icon.

Remove it with:

```bash
curl -fsSL https://raw.githubusercontent.com/NuclleaR/mp3directcutlinux/main/install.sh | bash -s -- --uninstall
```

Requires 64-bit Linux with GTK 3. Sound goes through ALSA, PulseAudio or PipeWire,
whichever the system has.

## Use

1. **Open folder** and click a file.
2. Mark the work:
   - drag on the waveform to select a range, then press **Delete** (`Del`);
   - press **Split here** (`S`) to split at the playhead.
3. Optionally type a new output name; the field starts with the current one.
4. Repeat for other files, then press **Apply**.

| Input | Action |
| --- | --- |
| Drag | Select a range |
| Drag a selection edge | Adjust the range |
| Click | Move the playhead |
| Wheel / Shift+wheel | Zoom / scroll |
| `Space` | Play or pause |
| `Del` | Mark the selection for deletion |
| `S` | Split at the playhead |
| `Ctrl+Z` | Undo |
| `Esc` | Clear the selection |
| `+` / `-` / `0` | Zoom in / out / fit |

## Build from source

The toolchain (Flutter, CMake, Ninja) is pinned with [mise](https://mise.jdx.dev):

```bash
mise install
mise exec -- flutter build linux --release
```

The app is then in `build/linux/x64/release/bundle/`. Building also needs a C/C++
compiler, `pkg-config` and the GTK 3 development files.

Run the tests with `mise exec -- flutter test`.

## Release

1. Set `version` in `pubspec.yaml`.
2. Commit.
3. Push the tag `v<version>` (for example `v0.0.1-beta`).

GitHub Actions then tests, builds and publishes the release. Versions with a suffix are
marked as pre-releases.

## Third-party code

- [minimp3](https://github.com/lieff/minimp3): MP3 decoding, CC0.
- [miniaudio](https://github.com/mackron/miniaudio): sound output, public domain or MIT-0.

Both are vendored in `native/third_party/`.
