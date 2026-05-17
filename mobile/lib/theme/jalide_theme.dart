import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeType { darkPurple, dark, light, dracula }

class JalideThemeVariant {
  final Color bg;
  final Color surface;
  final Color border;
  final Color accent;
  final Color textPri;
  final Color textMuted;
  final Color kwColor;
  final Color strColor;
  final Color commentColor;
  final Color varColor;
  final Color numColor;
  final Color fnColor;

  const JalideThemeVariant({
    required this.bg,
    required this.surface,
    required this.border,
    required this.accent,
    required this.textPri,
    required this.textMuted,
    required this.kwColor,
    required this.strColor,
    required this.commentColor,
    required this.varColor,
    required this.numColor,
    required this.fnColor,
  });

  static const darkPurple = JalideThemeVariant(
    bg: Color(0xFF120E20),
    surface: Color(0xFF181428),
    border: Color(0xFF261F3C),
    accent: Color(0xFFD67BFF),
    textPri: Color(0xFFF1EAFF),
    textMuted: Color(0xFF7A6F9B),
    kwColor: Color(0xFFFF79C6),
    strColor: Color(0xFF50FA7B),
    commentColor: Color(0xFF6B5E8C),
    varColor: Color(0xFF80DEEA),
    numColor: Color(0xFFFFB86C),
    fnColor: Color(0xFF00E5FF),
  );

  static const dark = JalideThemeVariant(
    bg: Color(0xFF0D0D0F),
    surface: Color(0xFF111114),
    border: Color(0xFF1E1E24),
    accent: Color(0xFFE07B1A),
    textPri: Color(0xFFCDD6F4),
    textMuted: Color(0xFF555566),
    kwColor: Color(0xFF7AA2F7),
    strColor: Color(0xFF9ECE6A),
    commentColor: Color(0xFF4A4A5A),
    varColor: Color(0xFF9D7CD8),
    numColor: Color(0xFFFF9E64),
    fnColor: Color(0xFF82AAFF),
  );

  static const light = JalideThemeVariant(
    bg: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE0E0E0),
    accent: Color(0xFFE07B1A),
    textPri: Color(0xFF2D2D2D),
    textMuted: Color(0xFF757575),
    kwColor: Color(0xFF1A73E8),
    strColor: Color(0xFF0D8040),
    commentColor: Color(0xFF9E9E9E),
    varColor: Color(0xFF8E44AD),
    numColor: Color(0xFFD84315),
    fnColor: Color(0xFF1A73E8),
  );

  static const dracula = JalideThemeVariant(
    bg: Color(0xFF282A36),
    surface: Color(0xFF343746),
    border: Color(0xFF44475A),
    accent: Color(0xFFFF79C6),
    textPri: Color(0xFFF8F8F2),
    textMuted: Color(0xFF6272A4),
    kwColor: Color(0xFFFF79C6),
    strColor: Color(0xFFF1FA8C),
    commentColor: Color(0xFF6272A4),
    varColor: Color(0xFFBD93F9),
    numColor: Color(0xFFBD93F9),
    fnColor: Color(0xFF50FA7B),
  );
}

class ThemeProvider extends InheritedNotifier<ValueNotifier<ThemeType>> {
  const ThemeProvider({
    super.key,
    required ValueNotifier<ThemeType> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static ThemeProvider of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<ThemeProvider>();
    assert(result != null, 'No ThemeProvider found in context');
    return result!;
  }

  ThemeType get themeType => notifier!.value;
  
  JalideThemeVariant get current {
    switch (themeType) {
      case ThemeType.darkPurple: return JalideThemeVariant.darkPurple;
      case ThemeType.dark: return JalideThemeVariant.dark;
      case ThemeType.light: return JalideThemeVariant.light;
      case ThemeType.dracula: return JalideThemeVariant.dracula;
    }
  }

  void setTheme(ThemeType type) {
    if (notifier!.value != type) {
      notifier!.value = type;
      _saveTheme(type);
    }
  }

  void toggleTheme() {
    final types = ThemeType.values;
    final currentIndex = types.indexOf(themeType);
    final nextIndex = (currentIndex + 1) % types.length;
    setTheme(types[nextIndex]);
  }

  Future<void> _saveTheme(ThemeType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_theme', type.name);
  }

  static Future<ThemeType> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('selected_theme');
      if (saved != null) {
        return ThemeType.values.byName(saved);
      }
    } catch (_) {}
    return ThemeType.darkPurple;
  }
}
