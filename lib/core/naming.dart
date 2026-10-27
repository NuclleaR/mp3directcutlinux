import 'dart:convert';

import 'mp3/parts.dart';

/// The file name without a trailing `.mp3` (any case).
String sourceBase(String fileName) =>
    fileName.toLowerCase().endsWith('.mp3') ? fileName.substring(0, fileName.length - 4) : fileName;

/// Output names (without extension), one per part, empty parts included so indices line up.
List<String> outputNames({
  required String sourceFileName,
  required String? outputName,
  required Map<int, String> partNames,
  required List<PartPlan> parts,
}) =>
    namesForAnchors(
      sourceFileName: sourceFileName,
      outputName: outputName,
      partNames: partNames,
      anchors: [for (final p in parts) p.anchorFrame],
    );

/// Same as [outputNames], from the parts' start frames (`[0, ...splits]`) alone.
List<String> namesForAnchors({
  required String sourceFileName,
  required String? outputName,
  required Map<int, String> partNames,
  required List<int> anchors,
}) {
  final base = outputName ?? sourceBase(sourceFileName);
  if (anchors.length == 1) return [base];
  return [for (var i = 0; i < anchors.length; i++) partNames[anchors[i]] ?? '$base part ${i + 1}'];
}

enum NameProblem { empty, slash, tooLong, duplicate }

NameProblem? checkName(String name) {
  if (name.trim().isEmpty) return NameProblem.empty;
  if (name.contains('/') || name.contains('\u0000')) return NameProblem.slash;
  if (utf8.encode('$name.mp3').length > 255) return NameProblem.tooLong;
  return null;
}
