import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'ui/home_page.dart';
import 'ui/theme/cut_palette.dart';

class App extends StatelessWidget {
  const App({super.key, this.locale});

  /// Forces a locale; only tests set it, the app follows the system.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // English first: any locale other than Ukrainian falls back to it.
      supportedLocales: const [Locale('en'), Locale('uk')],
      theme: CutPalette.light.toTheme(Brightness.light),
      darkTheme: CutPalette.dark.toTheme(Brightness.dark),
      home: const HomePage(),
    );
  }
}
