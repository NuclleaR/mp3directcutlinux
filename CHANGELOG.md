# Changelog

All notable changes to MP3 Direct Cut. Versions follow [Semantic Versioning](https://semver.org);
a version with a suffix such as `-beta` is a pre-release. Each section below becomes the
notes of its GitHub release.

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
