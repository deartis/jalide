import 'package:flutter/material.dart';
import '../theme/jalide_theme.dart';

class StatusBar extends StatelessWidget {
  final String languageName;
  final bool hasUnsavedChanges;
  final VoidCallback onTerminalToggle;

  const StatusBar({
    super.key,
    required this.languageName,
    required this.hasUnsavedChanges,
    required this.onTerminalToggle,
  });

  @override
  Widget build(BuildContext context) {
    final _theme = ThemeProvider.of(context).current;
    return Container(
      color: _theme.accent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTerminalToggle,
            child: _sbChip('⬡ Terminal'),
          ),
          const SizedBox(width: 12),
          _sbChip(languageName),
          const SizedBox(width: 12),
          _sbChip('UTF-8'),
          const Spacer(),
          if (hasUnsavedChanges)
            const Text(
              '●',
              style: TextStyle(color: Color(0xFF1A0A00), fontSize: 10),
            ),
        ],
      ),
    );
  }

  Widget _sbChip(String text) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF1A0A00),
      fontFamily: 'monospace',
      fontSize: 10,
      fontWeight: FontWeight.bold,
    ),
  );
}
