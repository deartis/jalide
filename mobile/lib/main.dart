import 'package:flutter/material.dart';
import 'package:jalide/screens/editor_screen.dart';

void main() {
  runApp(const JalideApp());
}

class JalideApp extends StatelessWidget {
  const JalideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JAL IDE',
      theme: ThemeData.dark(),
      home: const EditorScreen(),
    );
  }
}
