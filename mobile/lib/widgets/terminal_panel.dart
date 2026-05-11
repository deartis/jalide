import 'package:flutter/material.dart';
import '../theme/jalide_theme.dart';

class TerminalPanel extends StatelessWidget {
  final List<String> terminalLogs;
  final VoidCallback onClose;

  const TerminalPanel({
    super.key,
    required this.terminalLogs,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final _theme = ThemeProvider.of(context).current;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Container(
      height: keyboardVisible ? 200 : 160,
      margin: keyboardVisible ? const EdgeInsets.all(8) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: const Color(0xEE0D0D0F), // Semi-transparente
        borderRadius: keyboardVisible
            ? BorderRadius.circular(12)
            : BorderRadius.zero,
        border: Border(
          top: BorderSide(color: _theme.accent.withValues(alpha: 0.3)),
          left: keyboardVisible
              ? BorderSide(color: _theme.accent.withValues(alpha: 0.3))
              : BorderSide.none,
          right: keyboardVisible
              ? BorderSide(color: _theme.accent.withValues(alpha: 0.3))
              : BorderSide.none,
          bottom: keyboardVisible
              ? BorderSide(color: _theme.accent.withValues(alpha: 0.3))
              : BorderSide.none,
        ),
        boxShadow: [
          if (keyboardVisible)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: keyboardVisible
            ? BorderRadius.circular(12)
            : BorderRadius.zero,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: _theme.accent.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(Icons.terminal_outlined, size: 14, color: _theme.accent),
                  const SizedBox(width: 8),
                  Text(
                    'TERMINAL',
                    style: TextStyle(
                      color: _theme.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onClose,
                    icon: Icon(Icons.close, size: 14, color: _theme.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: terminalLogs.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '> ${terminalLogs[i]}',
                    style: const TextStyle(
                      color: Color(0xFF9ECE6A),
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
