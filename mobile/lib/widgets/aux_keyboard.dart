import 'package:flutter/material.dart';
import '../theme/jalide_theme.dart';

class AuxKeyboard extends StatelessWidget {
  final List<String> auxKeys;
  final bool ctrlActive;
  final Function(String) onKeyTap;

  const AuxKeyboard({
    super.key,
    required this.auxKeys,
    this.ctrlActive = false,
    required this.onKeyTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.of(context).current;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.border)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: auxKeys.map((key) {
          final isSpecial = key == 'Tab' ||
              key == 'Ctrl' ||
              key == '↑' ||
              key == '↓' ||
              key == '←' ||
              key == '→';
          final isCtrlSelected = key == 'Ctrl' && ctrlActive;

          return GestureDetector(
            onTap: () => onKeyTap(key),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: isCtrlSelected
                    ? theme.accent
                    : isSpecial
                        ? theme.accent.withValues(alpha: 0.12)
                        : const Color(0xFF1A1A20),
                border: Border.all(
                  color: isCtrlSelected
                      ? theme.accent
                      : isSpecial
                          ? theme.accent
                          : theme.border,
                  width: isSpecial ? 1 : 0.5,
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Center(
                child: Text(
                  key,
                  style: TextStyle(
                    color: isCtrlSelected
                        ? Colors.black87
                        : isSpecial
                            ? theme.accent
                            : theme.textMuted,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: isSpecial ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
