import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('uk'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MP3 Direct Cut'**
  String get appTitle;

  /// No description provided for @openFolder.
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get openFolder;

  /// No description provided for @noFolder.
  ///
  /// In en, this message translates to:
  /// **'Open a folder with MP3 files'**
  String get noFolder;

  /// No description provided for @noMp3InFolder.
  ///
  /// In en, this message translates to:
  /// **'No MP3 files in this folder'**
  String get noMp3InFolder;

  /// No description provided for @pickFileHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a file on the left'**
  String get pickFileHint;

  /// No description provided for @notMp3.
  ///
  /// In en, this message translates to:
  /// **'This does not look like an MP3: no audio frames found.'**
  String get notMp3;

  /// No description provided for @drawingWave.
  ///
  /// In en, this message translates to:
  /// **'Drawing the waveform…'**
  String get drawingWave;

  /// No description provided for @waveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not decode the file for the waveform, but you can still cut it.'**
  String get waveFailed;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'▶ Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'❚❚ Pause'**
  String get pause;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in (+)'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out (−)'**
  String get zoomOut;

  /// No description provided for @zoomFit.
  ///
  /// In en, this message translates to:
  /// **'Whole file'**
  String get zoomFit;

  /// No description provided for @snapToSilence.
  ///
  /// In en, this message translates to:
  /// **'Snap to silence'**
  String get snapToSilence;

  /// No description provided for @selectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Selected:'**
  String get selectedLabel;

  /// No description provided for @selectionNone.
  ///
  /// In en, this message translates to:
  /// **'nothing, drag across the waveform'**
  String get selectionNone;

  /// No description provided for @listenJoin.
  ///
  /// In en, this message translates to:
  /// **'▶ Listen to the join'**
  String get listenJoin;

  /// No description provided for @deleteSelection.
  ///
  /// In en, this message translates to:
  /// **'✂ Delete (Del)'**
  String get deleteSelection;

  /// No description provided for @splitAtCursor.
  ///
  /// In en, this message translates to:
  /// **'Split here (S)'**
  String get splitAtCursor;

  /// No description provided for @deletesTitle.
  ///
  /// In en, this message translates to:
  /// **'To be removed'**
  String get deletesTitle;

  /// No description provided for @deletesSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} pcs, {duration}'**
  String deletesSummary(int count, String duration);

  /// No description provided for @deletesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet. Select an ad on the waveform and press Del.'**
  String get deletesEmpty;

  /// No description provided for @joinShort.
  ///
  /// In en, this message translates to:
  /// **'▶ Join'**
  String get joinShort;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @showOnWave.
  ///
  /// In en, this message translates to:
  /// **'Show on the waveform'**
  String get showOnWave;

  /// No description provided for @partsTitle.
  ///
  /// In en, this message translates to:
  /// **'Parts'**
  String get partsTitle;

  /// No description provided for @removeSplit.
  ///
  /// In en, this message translates to:
  /// **'Remove split'**
  String get removeSplit;

  /// No description provided for @outputName.
  ///
  /// In en, this message translates to:
  /// **'Output name'**
  String get outputName;

  /// No description provided for @durations.
  ///
  /// In en, this message translates to:
  /// **'Was {before} · will be {after}'**
  String durations(String before, String after);

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo last (Ctrl+Z)'**
  String get undo;

  /// No description provided for @hintDrag.
  ///
  /// In en, this message translates to:
  /// **'Drag: select'**
  String get hintDrag;

  /// No description provided for @hintEdge.
  ///
  /// In en, this message translates to:
  /// **'Drag a selection edge: adjust'**
  String get hintEdge;

  /// No description provided for @hintClick.
  ///
  /// In en, this message translates to:
  /// **'Click: place the cursor'**
  String get hintClick;

  /// No description provided for @hintWheel.
  ///
  /// In en, this message translates to:
  /// **'Wheel: zoom · Shift+wheel: scroll'**
  String get hintWheel;

  /// No description provided for @hintKeys.
  ///
  /// In en, this message translates to:
  /// **'Space play · Del delete · S split · Esc clear selection'**
  String get hintKeys;

  /// No description provided for @queueCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file in the queue} other{{count} files in the queue}}'**
  String queueCount(int count);

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @applying.
  ///
  /// In en, this message translates to:
  /// **'Applying {done}/{total}…'**
  String applying(int done, int total);

  /// No description provided for @applyResults.
  ///
  /// In en, this message translates to:
  /// **'Written: {written} · Conflicts: {conflicts} · Errors: {errors} · Skipped: {skipped}'**
  String applyResults(int written, int conflicts, int errors, int skipped);

  /// No description provided for @obsoleteOutputs.
  ///
  /// In en, this message translates to:
  /// **'Earlier outputs no longer produced (left in place): {names}'**
  String obsoleteOutputs(String names);

  /// No description provided for @statusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get statusDone;

  /// No description provided for @statusConflict.
  ///
  /// In en, this message translates to:
  /// **'Conflict'**
  String get statusConflict;

  /// No description provided for @statusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get statusError;

  /// No description provided for @statusStale.
  ///
  /// In en, this message translates to:
  /// **'Source file changed'**
  String get statusStale;

  /// No description provided for @clearStale.
  ///
  /// In en, this message translates to:
  /// **'Mark as reviewed'**
  String get clearStale;

  /// No description provided for @conflictOutput.
  ///
  /// In en, this message translates to:
  /// **'{name}: a different file already exists in cut/'**
  String conflictOutput(String name);

  /// No description provided for @titleNotUpdated.
  ///
  /// In en, this message translates to:
  /// **'{name}: tags copied, title not updated'**
  String titleNotUpdated(String name);

  /// No description provided for @nameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Name is empty'**
  String get nameEmpty;

  /// No description provided for @nameSlash.
  ///
  /// In en, this message translates to:
  /// **'Name cannot contain /'**
  String get nameSlash;

  /// No description provided for @nameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Name is too long'**
  String get nameTooLong;

  /// No description provided for @nameDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Another output has the same name'**
  String get nameDuplicate;

  /// No description provided for @queueFileBroken.
  ///
  /// In en, this message translates to:
  /// **'The queue file was damaged; a copy was kept as {name} and a new queue started.'**
  String queueFileBroken(String name);

  /// No description provided for @queueSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the queue: {error}'**
  String queueSaveFailed(String error);

  /// No description provided for @clearQueue.
  ///
  /// In en, this message translates to:
  /// **'Clear queue'**
  String get clearQueue;

  /// No description provided for @clearQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear the queue?'**
  String get clearQueueTitle;

  /// No description provided for @clearQueueBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file will lose its marks, splits and names. Done files stay. This cannot be undone.} other{{count} files will lose their marks, splits and names. Done files stay. This cannot be undone.}}'**
  String clearQueueBody(int count);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @conflictsTitle.
  ///
  /// In en, this message translates to:
  /// **'Files already in cut/'**
  String get conflictsTitle;

  /// No description provided for @conflictsBody.
  ///
  /// In en, this message translates to:
  /// **'cut/ already has files with these names, and this app did not write them. Overwrite them, or reset the file\'s changes and leave cut/ as it is.'**
  String get conflictsBody;

  /// No description provided for @discardChanges.
  ///
  /// In en, this message translates to:
  /// **'Reset changes'**
  String get discardChanges;

  /// No description provided for @overwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get overwrite;

  /// No description provided for @overwriteTitle.
  ///
  /// In en, this message translates to:
  /// **'Overwrite?'**
  String get overwriteTitle;

  /// No description provided for @overwriteBody.
  ///
  /// In en, this message translates to:
  /// **'{names} in cut/ will be replaced. The old file cannot be brought back.'**
  String overwriteBody(String names);

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @sortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortLabel;

  /// No description provided for @sortByName.
  ///
  /// In en, this message translates to:
  /// **'By name'**
  String get sortByName;

  /// No description provided for @sortByDate.
  ///
  /// In en, this message translates to:
  /// **'By date, newest first'**
  String get sortByDate;

  /// No description provided for @menuAbout.
  ///
  /// In en, this message translates to:
  /// **'About MP3 Direct Cut'**
  String get menuAbout;

  /// No description provided for @menuCheckUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get menuCheckUpdates;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Cuts ads and outros out of MP3 files and splits long files into parts, frame by frame and without re-encoding.'**
  String get aboutDescription;

  /// No description provided for @aboutSource.
  ///
  /// In en, this message translates to:
  /// **'Source code on GitHub'**
  String get aboutSource;

  /// No description provided for @updateTitle.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updateTitle;

  /// No description provided for @updateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get updateChecking;

  /// No description provided for @updateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You have the newest version, {version}.'**
  String updateUpToDate(String version);

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is out; you have {current}.'**
  String updateAvailable(String version, String current);

  /// No description provided for @updateNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'This copy was not installed by install.sh, so it cannot update itself. Get the new version on GitHub.'**
  String get updateNotInstalled;

  /// No description provided for @updateInstalling.
  ///
  /// In en, this message translates to:
  /// **'Downloading and installing {version}…'**
  String updateInstalling(String version);

  /// No description provided for @updateInstalled.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is installed. Restart now?'**
  String updateInstalled(String version);

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {error}'**
  String updateFailed(String error);

  /// No description provided for @updateBanner.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is out'**
  String updateBanner(String version);

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateNow;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @openReleasePage.
  ///
  /// In en, this message translates to:
  /// **'Open the release'**
  String get openReleasePage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'uk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
