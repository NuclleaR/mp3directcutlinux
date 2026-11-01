# Changelog

All notable changes to MP3 Direct Cut. Versions follow [Semantic Versioning](https://semver.org);
a version with a suffix such as `-beta` is a pre-release. Each section below becomes the
notes of its GitHub release.

## [1.0.0-beta] - 2026-11-01

### Added

- A ☰ menu in the window's title bar with About and Check for updates. The title bar now
  looks the same on every desktop.
- In-app updates. At startup the app quietly checks GitHub and shows a line at the top of
  the window when a newer version is out. Update downloads it, replaces the copy that
  `install.sh` installed (the old one stays if anything fails) and offers a restart.
- A sort toggle above the file list: by name, or by date with the newest files first.
- Drag the edge between the file list and the editor to make the list wider or narrower.
- The sort order and the list width are remembered in
  `~/.config/mp3-direct-cut/settings.json`; nothing is written into the opened folder.

## [0.0.2] - 2026-10-27

### Added

- When Apply finds files in `cut/` with the same names that the app did not write, a
  dialog lists them. For each file you can reset its changes, which leaves `cut/` as it
  is, or overwrite after a confirmation, which replaces only those files.

## [0.0.1] - 2026-10-27

First stable release: everything in 0.0.1-beta, plus the following.

### Added

- A Clear queue button. After a confirmation it drops the marks, splits and names of every
  file not yet applied. Files already done stay as they are, and the app still knows which
  files in `cut/` it wrote itself.

## [0.0.1-beta] - 2026-10-27

First public build.

### Added

- Open a folder and list its MP3 files; click one to see its frame waveform, with an
  overview strip for long files.
- Mark ranges for deletion and split files at the playhead; undo, snap to silence, zoom.
- Rename outputs; every part of a split file gets its own name, prefilled with the default.
- Playback that skips marked ranges, and "Listen to the join" around a cut.
- A work queue saved in the folder as `.mp3directcut-queue.json`; Apply writes every queued
  file into `cut/` without re-encoding and never touches the originals.
- ID3 tags copied from the original, with the title set to the new name.
- English and Ukrainian interface.
- An installer that installs the newest GitHub release for the current user, with a menu
  entry and icon.
