// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'MP3 Direct Cut';

  @override
  String get openFolder => 'Відкрити теку';

  @override
  String get noFolder => 'Відкрий теку з MP3-файлами';

  @override
  String get noMp3InFolder => 'У цій теці немає MP3-файлів';

  @override
  String get pickFileHint => 'Вибери файл ліворуч';

  @override
  String get notMp3 => 'Це не схоже на MP3: не знайшов жодного аудіокадру.';

  @override
  String get drawingWave => 'Малюю хвилю…';

  @override
  String get waveFailed =>
      'Не вдалося розкодувати файл для хвилі, але вирізати все одно можна.';

  @override
  String get play => '▶ Грати';

  @override
  String get pause => '❚❚ Пауза';

  @override
  String get zoomIn => 'Збільшити (+)';

  @override
  String get zoomOut => 'Зменшити (−)';

  @override
  String get zoomFit => 'Весь файл';

  @override
  String get snapToSilence => 'Прилипати до тиші';

  @override
  String get selectedLabel => 'Виділено:';

  @override
  String get selectionNone => 'нічого, протягни мишкою по хвилі';

  @override
  String get listenJoin => '▶ Прослухати стик';

  @override
  String get deleteSelection => '✂ Видалити (Del)';

  @override
  String get splitAtCursor => 'Розділити тут (S)';

  @override
  String get deletesTitle => 'Що буде вирізано';

  @override
  String deletesSummary(int count, String duration) {
    return '$count шт., $duration';
  }

  @override
  String get deletesEmpty =>
      'Поки нічого. Виділи рекламу на хвилі й натисни Del.';

  @override
  String get joinShort => '▶ Стик';

  @override
  String get restore => 'Повернути';

  @override
  String get showOnWave => 'Показати на хвилі';

  @override
  String get partsTitle => 'Частини';

  @override
  String get removeSplit => 'Прибрати розріз';

  @override
  String get outputName => 'Назва результату';

  @override
  String durations(String before, String after) {
    return 'Було $before · стане $after';
  }

  @override
  String get undo => 'Скасувати останнє (Ctrl+Z)';

  @override
  String get hintDrag => 'Протягни мишкою: виділити';

  @override
  String get hintEdge => 'Тягни край виділення: підправити';

  @override
  String get hintClick => 'Клік: поставити курсор';

  @override
  String get hintWheel => 'Колесо: зум · Shift+колесо: прокрутка';

  @override
  String get hintKeys =>
      'Пробіл грати · Del видалити · S розділити · Esc зняти виділення';

  @override
  String queueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файлу в черзі',
      many: '$count файлів у черзі',
      few: '$count файли у черзі',
      one: '$count файл у черзі',
    );
    return '$_temp0';
  }

  @override
  String get apply => 'Застосувати';

  @override
  String applying(int done, int total) {
    return 'Застосовую $done/$total…';
  }

  @override
  String applyResults(int written, int conflicts, int errors, int skipped) {
    return 'Записано: $written · Конфлікти: $conflicts · Помилки: $errors · Пропущено: $skipped';
  }

  @override
  String obsoleteOutputs(String names) {
    return 'Старі результати, яких більше немає (лишились на місці): $names';
  }

  @override
  String get statusDone => 'Готово';

  @override
  String get statusConflict => 'Конфлікт';

  @override
  String get statusError => 'Помилка';

  @override
  String get statusStale => 'Файл-джерело змінився';

  @override
  String get clearStale => 'Позначити перевіреним';

  @override
  String conflictOutput(String name) {
    return '$name: у cut/ вже є інший файл';
  }

  @override
  String titleNotUpdated(String name) {
    return '$name: теги скопійовано, назву не оновлено';
  }

  @override
  String get nameEmpty => 'Назва порожня';

  @override
  String get nameSlash => 'Назва не може містити /';

  @override
  String get nameTooLong => 'Назва задовга';

  @override
  String get nameDuplicate => 'Інший результат має таку саму назву';

  @override
  String queueFileBroken(String name) {
    return 'Файл черги пошкоджений: копію збережено як $name, почато нову чергу.';
  }

  @override
  String queueSaveFailed(String error) {
    return 'Не вдалося зберегти чергу: $error';
  }
}
