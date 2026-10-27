// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MP3 Direct Cut';

  @override
  String get openFolder => 'Open folder';

  @override
  String get noFolder => 'Open a folder with MP3 files';

  @override
  String get noMp3InFolder => 'No MP3 files in this folder';

  @override
  String get pickFileHint => 'Pick a file on the left';

  @override
  String get notMp3 => 'This does not look like an MP3: no audio frames found.';

  @override
  String get drawingWave => 'Drawing the waveform…';

  @override
  String get waveFailed =>
      'Could not decode the file for the waveform, but you can still cut it.';

  @override
  String get play => '▶ Play';

  @override
  String get pause => '❚❚ Pause';

  @override
  String get zoomIn => 'Zoom in (+)';

  @override
  String get zoomOut => 'Zoom out (−)';

  @override
  String get zoomFit => 'Whole file';

  @override
  String get snapToSilence => 'Snap to silence';

  @override
  String get selectedLabel => 'Selected:';

  @override
  String get selectionNone => 'nothing, drag across the waveform';

  @override
  String get listenJoin => '▶ Listen to the join';

  @override
  String get deleteSelection => '✂ Delete (Del)';

  @override
  String get splitAtCursor => 'Split here (S)';

  @override
  String get deletesTitle => 'To be removed';

  @override
  String deletesSummary(int count, String duration) {
    return '$count pcs, $duration';
  }

  @override
  String get deletesEmpty =>
      'Nothing yet. Select an ad on the waveform and press Del.';

  @override
  String get joinShort => '▶ Join';

  @override
  String get restore => 'Restore';

  @override
  String get showOnWave => 'Show on the waveform';

  @override
  String get partsTitle => 'Parts';

  @override
  String get removeSplit => 'Remove split';

  @override
  String get outputName => 'Output name';

  @override
  String durations(String before, String after) {
    return 'Was $before · will be $after';
  }

  @override
  String get undo => 'Undo last (Ctrl+Z)';

  @override
  String get hintDrag => 'Drag: select';

  @override
  String get hintEdge => 'Drag a selection edge: adjust';

  @override
  String get hintClick => 'Click: place the cursor';

  @override
  String get hintWheel => 'Wheel: zoom · Shift+wheel: scroll';

  @override
  String get hintKeys =>
      'Space play · Del delete · S split · Esc clear selection';

  @override
  String queueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files in the queue',
      one: '1 file in the queue',
    );
    return '$_temp0';
  }

  @override
  String get apply => 'Apply';

  @override
  String applying(int done, int total) {
    return 'Applying $done/$total…';
  }

  @override
  String applyResults(int written, int conflicts, int errors, int skipped) {
    return 'Written: $written · Conflicts: $conflicts · Errors: $errors · Skipped: $skipped';
  }

  @override
  String obsoleteOutputs(String names) {
    return 'Earlier outputs no longer produced (left in place): $names';
  }

  @override
  String get statusDone => 'Done';

  @override
  String get statusConflict => 'Conflict';

  @override
  String get statusError => 'Error';

  @override
  String get statusStale => 'Source file changed';

  @override
  String get clearStale => 'Mark as reviewed';

  @override
  String conflictOutput(String name) {
    return '$name: a different file already exists in cut/';
  }

  @override
  String titleNotUpdated(String name) {
    return '$name: tags copied, title not updated';
  }

  @override
  String get nameEmpty => 'Name is empty';

  @override
  String get nameSlash => 'Name cannot contain /';

  @override
  String get nameTooLong => 'Name is too long';

  @override
  String get nameDuplicate => 'Another output has the same name';

  @override
  String queueFileBroken(String name) {
    return 'The queue file was damaged; a copy was kept as $name and a new queue started.';
  }

  @override
  String queueSaveFailed(String error) {
    return 'Could not save the queue: $error';
  }
}
