import 'package:flutter/material.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final TextEditingController controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JALIDE'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: controller,
          expands: true,
          maxLines: null,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Comece a programar...',
          ),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}