import 'package:flutter/material.dart';
import 'package:jalide/screens/editor_screen.dart';
import 'package:jalide/theme/jalide_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initialTheme = await ThemeProvider.loadTheme();
  
  runApp(
    ThemeProvider(
      notifier: ValueNotifier(initialTheme),
      child: const JalideApp(),
    ),
  );
}

class JalideApp extends StatelessWidget {
  const JalideApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeType = ThemeProvider.of(context).themeType;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JAL IDE',
      theme: themeType == ThemeType.light ? ThemeData.light() : ThemeData.dark(),
      home: const EditorScreen(),
    );
  }
}