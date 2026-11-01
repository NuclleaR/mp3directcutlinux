import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'state/settings_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(
    overrides: [settingsStoreProvider.overrideWithValue(FileSettingsStore.forUser())],
    child: const App(),
  ));
}
