import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analysis/file_analysis.dart';
import 'folder_controller.dart';

/// The file open in the editor; cleared whenever another folder is opened.
class SelectedFileController extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(folderProvider.select((f) => f?.dir.path));
    return null;
  }

  void select(String? fileName) => state = fileName;
}

final selectedFileProvider = NotifierProvider<SelectedFileController, String?>(SelectedFileController.new);

/// Parsed layout and waveform of a file, by path. Kept for the whole session.
final fileAnalysisProvider = FutureProvider.family<FileAnalysis, String>((ref, path) => analyzeFile(path));

/// Whether a file looks like an MP3, for greying out rows in the file list.
final probeProvider = FutureProvider.family<bool, String>((ref, path) => probeMp3(path));
