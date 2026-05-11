import 'package:flutter/material.dart';
import '../theme/jalide_theme.dart';

class EditorTabsBar extends StatelessWidget {
  final List<Map<String, dynamic>> tabs;
  final int activeIndex;
  final Function(int) onTabTap;
  final Function(int) onCloseTab;

  const EditorTabsBar({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.onTabTap,
    required this.onCloseTab,
  });

  @override
  Widget build(BuildContext context) {
    final _theme = ThemeProvider.of(context).current;
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Color(0xFF0F0F12),
        border: Border(bottom: BorderSide(color: _theme.border)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (_, i) {
          final isActive = i == activeIndex;
          final tab = tabs[i];
          return GestureDetector(
            onTap: () => onTabTap(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isActive ? _theme.surface : Colors.transparent,
                border: Border(
                  right: BorderSide(color: _theme.border),
                  bottom: BorderSide(
                    color: isActive ? _theme.accent : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (isActive)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: _theme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Text(
                    tab['name'] as String,
                    style: TextStyle(
                      color: isActive ? _theme.textPri : _theme.textMuted,
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => onCloseTab(i),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: isActive
                          ? _theme.textMuted
                          : _theme.textMuted.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
