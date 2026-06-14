import 'package:flutter/material.dart';
import '../theme/jalide_theme.dart';

class StatusBar extends StatelessWidget {
  final String languageName;
  final bool hasUnsavedChanges;
  final VoidCallback onTerminalToggle;
  final VoidCallback? onLanguageTap;

  const StatusBar({
    super.key,
    required this.languageName,
    required this.hasUnsavedChanges,
    required this.onTerminalToggle,
    this.onLanguageTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.of(context).current;
    return Container(
      color: theme.accent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTerminalToggle,
            child: _sbChip(theme, '⬡ Terminal'),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onLanguageTap,
            behavior: HitTestBehavior.opaque,
            child: _sbChip(theme, languageName),
          ),
          const SizedBox(width: 12),
          _sbChip(theme, 'UTF-8'),
          const Spacer(),
          if (hasUnsavedChanges)
            Text(
              '●',
              style: TextStyle(color: theme.bg, fontSize: 10),
            ),
        ],
      ),
    );
  }

  Widget _sbChip(JalideThemeVariant theme, String text) => Text(
    text,
    style: TextStyle(
      color: theme.bg,
      fontFamily: 'monospace',
      fontSize: 10,
      fontWeight: FontWeight.bold,
    ),
  );
}
