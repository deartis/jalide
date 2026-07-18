import 'package:flutter/material.dart';
import 'package:jalide/screens/editor_screen.dart';
import 'package:jalide/services/ssh_foreground_service.dart';
import 'package:jalide/theme/jalide_theme.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:jalide/l10n/app_localizations.dart';

late ValueNotifier<ThemeType> _themeNotifier;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa porta de comunicação do Foreground Service (obrigatório antes do runApp)
  SshForegroundService.initialize();

  final initialTheme = await ThemeProvider.loadTheme();
  _themeNotifier = ValueNotifier(initialTheme);

  runApp(ThemeProvider(notifier: _themeNotifier, child: const JalideApp()));
}

class JalideApp extends StatelessWidget {
  const JalideApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeType = ThemeProvider.of(context).themeType;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JAL IDE',
      theme: themeType == ThemeType.light
          ? ThemeData.light()
          : ThemeData.dark(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', ''), Locale('en', '')],
      home: const EditorScreen(),
    );
  }
}
