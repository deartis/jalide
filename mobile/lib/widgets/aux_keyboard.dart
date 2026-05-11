import 'package:flutter/material.dart';
import '../theme/jalide_theme.dart';

class AuxKeyboard extends StatelessWidget {
  final List<String> auxKeys;
  final Function(String) onKeyTap;

  const AuxKeyboard({
    super.key,
    required this.auxKeys,
    required this.onKeyTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: JalideTheme.surface,
        border: Border(top: BorderSide(color: JalideTheme.border)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: auxKeys.map((key) {
          final isSpecial = key == 'Tab';
          return GestureDetector(
            onTap: () => onKeyTap(key),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: isSpecial
                    ? JalideTheme.accent.withValues(alpha: 0.12)
                    : const Color(0xFF1A1A20),
                border: Border.all(
                  color: isSpecial ? JalideTheme.accent : JalideTheme.border,
                  width: isSpecial ? 1 : 0.5,
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                key,
                style: TextStyle(
                  color: isSpecial ? JalideTheme.accent : JalideTheme.textMuted,
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: isSpecial ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
